using System.Collections.Concurrent;
using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text;

namespace StormMSN.Classic;

// A raw MSNP7 byte stream transported over the Storm MSN WSS bridge.
// WebSocket frame boundaries are NOT MSN protocol packet boundaries.
public sealed record MsnFrame(string[] Words, byte[] Payload) {
    public string Cmd => Words.Length == 0 ? "" : Words[0];
}

public sealed class MsnWire : IAsyncDisposable {
    private readonly ClientWebSocket _ws = new();
    private readonly CancellationTokenSource _stop = new();
    private readonly SemaphoreSlim _sendLock = new(1, 1);
    private readonly List<byte> _buffer = [];
    private readonly ConcurrentDictionary<string, ConcurrentQueue<TaskCompletionSource<MsnFrame>>> _pending = new();
    private Task? _readTask;
    public event Action<MsnFrame>? Frame;
    public event Action? Closed;

    private MsnWire() { _ws.Options.KeepAliveInterval = TimeSpan.FromSeconds(25); }

    public static async Task<MsnWire> ConnectAsync(int port) {
        var wire = new MsnWire();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(16));
        await wire._ws.ConnectAsync(new Uri($"wss://msn.hoststorm.com.br/ws/{port}"), timeout.Token);
        wire._readTask = wire.ReadLoop();
        return wire;
    }

    public async Task SendAsync(string line, byte[]? body = null) {
        var header = Encoding.UTF8.GetBytes(line + "\r\n");
        byte[] bytes;
        if (body is null) bytes = header;
        else {
            bytes = new byte[header.Length + body.Length];
            Buffer.BlockCopy(header, 0, bytes, 0, header.Length);
            Buffer.BlockCopy(body, 0, bytes, header.Length, body.Length);
        }
        await _sendLock.WaitAsync();
        try {
            await _ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Binary, true, _stop.Token);
        } finally { _sendLock.Release(); }
    }

    public async Task<MsnFrame> RequestAsync(string line, string operation) {
        var tcs = new TaskCompletionSource<MsnFrame>(TaskCreationOptions.RunContinuationsAsynchronously);
        _pending.GetOrAdd(operation, _ => new ConcurrentQueue<TaskCompletionSource<MsnFrame>>()).Enqueue(tcs);
        await SendAsync(line);
        try { return await tcs.Task.WaitAsync(TimeSpan.FromSeconds(18)); }
        catch (TimeoutException) { throw new TimeoutException($"O Storm MSN não respondeu a {operation}."); }
    }

    private async Task ReadLoop() {
        var bytes = new byte[8192];
        try {
            while (!_stop.IsCancellationRequested && _ws.State == WebSocketState.Open) {
                var read = await _ws.ReceiveAsync(new ArraySegment<byte>(bytes), _stop.Token);
                if (read.MessageType == WebSocketMessageType.Close) break;
                for (int i = 0; i < read.Count; i++) _buffer.Add(bytes[i]);
                if (_buffer.Count > 2_000_000) throw new InvalidDataException("Pacote MSN acima do limite.");
                Parse();
            }
        } catch (OperationCanceledException) { }
          catch (WebSocketException) { }
          catch (Exception) { }
        finally {
            foreach (var q in _pending.Values)
                while (q.TryDequeue(out var item)) item.TrySetException(new IOException("Servidor MSN desconectou."));
            Closed?.Invoke();
        }
    }

    private void Parse() {
        while (_buffer.Count > 0) {
            int end = -1;
            for (int i = 0; i < _buffer.Count - 1; i++)
                if (_buffer[i] == 13 && _buffer[i + 1] == 10) { end = i; break; }
            if (end < 0) return;
            string line = Encoding.UTF8.GetString(_buffer.GetRange(0, end).ToArray());
            string[] words = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            int count = 0;
            if (words.Length > 0 && words[0] == "MSG" &&
                (!int.TryParse(words[^1], out count) || count < 0 || count > 1_000_000))
                throw new InvalidDataException("Tamanho MSG inválido.");
            if (_buffer.Count < end + 2 + count) return;
            byte[] payload = count == 0 ? [] : _buffer.GetRange(end + 2, count).ToArray();
            _buffer.RemoveRange(0, end + 2 + count);
            var frame = new MsnFrame(words, payload);
            if (words.Length > 0 && words[0].Length == 3 && words[0].All(char.IsAsciiDigit)) {
                var ex = new InvalidOperationException(words[0] switch {
                    "911" => "E-mail ou senha incorretos.",
                    "205" => "Conta não encontrada no Storm MSN.",
                    "215" => "O contato já existe na lista.",
                    _ => "Servidor respondeu com erro MSN " + words[0]
                });
                foreach (var q in _pending.Values)
                    while (q.TryDequeue(out var pending)) pending.TrySetException(ex);
                continue;
            }
            if (_pending.TryGetValue(frame.Cmd, out var queue) && queue.TryDequeue(out var waiter))
                waiter.TrySetResult(frame);
            try { Frame?.Invoke(frame); } catch { /* A UI callback must not stop the network loop. */ }
        }
    }

    public async ValueTask DisposeAsync() {
        _stop.Cancel();
        try { _ws.Abort(); _ws.Dispose(); } catch { }
        if (_readTask != null) try { await _readTask.WaitAsync(TimeSpan.FromSeconds(2)); } catch { }
        _sendLock.Dispose();
        _stop.Dispose();
    }
}

public sealed class MsnBuddy {
    public string Email { get; }
    public string Name { get; set; }
    public string Presence { get; set; } = "FLN";
    public bool Favorite { get; set; }
    public bool IsOnline => Presence != "FLN" && Presence != "HDN";
    public string StatusName => Presence switch {
        "NLN" => "Disponível", "BSY" => "Ocupado", "AWY" => "Ausente", "HDN" => "Aparecer offline", _ => "Offline"
    };
    public Uri Avatar => new("https://msn.hoststorm.com.br/api/mobile/avatar/" + Uri.EscapeDataString(Email));
    public MsnBuddy(string email, string? name = null) {
        Email = email.ToLowerInvariant();
        Name = string.IsNullOrWhiteSpace(name) ? Email : name;
    }
}

public sealed class MsnSession : IAsyncDisposable {
    private MsnWire? _notification;
    private readonly ConcurrentDictionary<string, MsnWire> _switchboards = new();
    private readonly ConcurrentDictionary<string, ConcurrentQueue<string>> _queued = new();
    private readonly ConcurrentDictionary<string, byte> _opening = new();
    private readonly ConcurrentQueue<string> _requests = new();
    private readonly Dictionary<string, MsnBuddy> _contacts = new(StringComparer.OrdinalIgnoreCase);
    private readonly object _sync = new();
    private int _tx = 10;
    private bool _explicitExit;
    public string Email { get; private set; } = "";
    public bool Online { get; private set; }
    public MsnBuddy[] Contacts { get { lock (_sync) return _contacts.Values.ToArray(); } }
    public event Action? ContactsChanged;
    public event Action<string, string, bool>? MessageReceived;
    public event Action<string>? Error;
    public event Action? Disconnected;

    public async Task LoginAsync(string email, string password, string status) {
        Email = email.Trim().ToLowerInvariant();
        if (!Email.Contains('@') || password.Length == 0) throw new ArgumentException("Informe e-mail e senha.");
        _explicitExit = false;
        _notification = await MsnWire.ConnectAsync(1863);
        _notification.Frame += OnNotification;
        _notification.Closed += () => {
            if (!_explicitExit && Online) { Online = false; Disconnected?.Invoke(); }
        };
        try {
            var ver = await _notification.RequestAsync("VER 1 MSNP7 CVR0", "VER");
            if (!ver.Words.Contains("MSNP7")) throw new InvalidOperationException("Servidor incompatível com MSNP7.");
            await _notification.RequestAsync("INF 2", "INF");
            var challenge = await _notification.RequestAsync("USR 3 MD5 I " + Email, "USR");
            if (challenge.Words.Length < 5) throw new InvalidOperationException("Desafio de login inválido.");
            var digest = Convert.ToHexString(MD5.HashData(Encoding.UTF8.GetBytes(challenge.Words[4] + password))).ToLowerInvariant();
            var auth = await _notification.RequestAsync("USR 4 MD5 S " + digest, "USR");
            if (auth.Words.Length < 3 || auth.Words[2] != "OK") throw new InvalidOperationException("Credenciais recusadas.");
            await _notification.RequestAsync("SYN 5 0", "SYN");
            await _notification.RequestAsync("CHG 6 " + status, "CHG");
            Online = true;
            ContactsChanged?.Invoke();
        } catch {
            await LogoutAsync();
            throw;
        }
    }

    private MsnBuddy Ensure(string email) {
        email = email.ToLowerInvariant();
        if (!_contacts.TryGetValue(email, out var buddy))
            _contacts[email] = buddy = new MsnBuddy(email);
        return buddy;
    }

    private void OnNotification(MsnFrame packet) {
        var w = packet.Words;
        try {
            switch (packet.Cmd) {
                case "LST":
                    if (w.Length >= 8 && w[2] == "FL" && w[6].Contains('@')) {
                        lock (_sync) {
                            var buddy = Ensure(w[6]);
                            string title = Uri.UnescapeDataString(w[7]);
                            if (title.Length > 0 && !title.Contains('@')) buddy.Name = title;
                        }
                        ContactsChanged?.Invoke();
                    }
                    break;
                case "ADD":
                    if (w.Length >= 5 && w[2] == "FL" && w[4].Contains('@')) {
                        lock (_sync) Ensure(w[4]);
                        ContactsChanged?.Invoke();
                    }
                    break;
                case "NLN":
                case "ILN": {
                    int index = packet.Cmd == "ILN" ? 3 : 2;
                    int presence = packet.Cmd == "ILN" ? 2 : 1;
                    if (w.Length > index && w[index].Contains('@')) {
                        lock (_sync) {
                            var b = Ensure(w[index]);
                            b.Presence = w[presence];
                            if (w.Length > index + 1) {
                                string nickname = Uri.UnescapeDataString(w[index + 1]);
                                if (nickname.Length > 0 && !nickname.Contains('@')) b.Name = nickname;
                            }
                        }
                        ContactsChanged?.Invoke();
                    }
                    break;
                }
                case "FLN":
                    if (w.Length > 1) {
                        lock (_sync) if (_contacts.TryGetValue(w[1], out var b)) b.Presence = "FLN";
                        ContactsChanged?.Invoke();
                    }
                    break;
                case "XFR":
                    if (w.Length > 5 && w[2] == "SB" && _requests.TryDequeue(out string? peer))
                        _ = OpenOutgoing(peer, w[5]);
                    break;
                case "RNG":
                    if (w.Length >= 6 && w[3] == "CKI" && w[5].Contains('@')) {
                        string peer = w[5].ToLowerInvariant();
                        lock (_sync) Ensure(peer);
                        ContactsChanged?.Invoke();
                        _ = OpenIncoming(peer, w[1], w[4]);
                    }
                    break;
            }
        } catch (Exception e) { Error?.Invoke(e.Message); }
    }

    private async Task OpenOutgoing(string peer, string token) {
        try {
            MsnWire board = await MsnWire.ConnectAsync(1864);
            board.Frame += f => OnSwitchboard(peer, board, f);
            _switchboards[peer] = board;
            await board.RequestAsync("USR 1 " + Email + " " + token, "USR");
            await board.RequestAsync("CAL 2 " + peer, "CAL");
            _opening.TryRemove(peer, out _);
        } catch (Exception e) { _opening.TryRemove(peer, out _); Error?.Invoke("Conversa: " + e.Message); }
    }

    private async Task OpenIncoming(string peer, string sessionId, string token) {
        try {
            MsnWire board = await MsnWire.ConnectAsync(1864);
            board.Frame += f => OnSwitchboard(peer, board, f);
            _switchboards[peer] = board;
            await board.RequestAsync($"ANS 1 {Email} {token} {sessionId}", "ANS");
            await Flush(peer);
        } catch (Exception e) { Error?.Invoke("Recebimento: " + e.Message); }
    }

    private void OnSwitchboard(string peer, MsnWire board, MsnFrame f) {
        if (f.Cmd == "JOI") { _ = Flush(peer); return; }
        if (f.Cmd == "BYE") { _switchboards.TryRemove(peer, out _); _ = board.DisposeAsync(); return; }
        if (f.Cmd != "MSG") return;
        int start = -1;
        for (int i = 0; i + 3 < f.Payload.Length; i++)
            if (f.Payload[i] == 13 && f.Payload[i + 1] == 10 && f.Payload[i + 2] == 13 && f.Payload[i + 3] == 10) {
                start = i + 4; break;
            }
        if (start < 0) return;
        string headers = Encoding.UTF8.GetString(f.Payload, 0, start);
        if (!headers.Contains("text/plain", StringComparison.OrdinalIgnoreCase)) return;
        string body = Encoding.UTF8.GetString(f.Payload, start, f.Payload.Length - start);
        if (body.Length == 0) return;
        string from = f.Words.Length > 1 && f.Words[1].Contains('@') ? f.Words[1].ToLowerInvariant() : peer;
        MessageReceived?.Invoke(from, body, false);
    }

    private async Task Flush(string peer) {
        if (!_switchboards.TryGetValue(peer, out var board) || !_queued.TryRemove(peer, out var queue)) return;
        while (queue.TryDequeue(out var body)) {
            try { await SendFrame(board, body); }
            catch (Exception e) { Error?.Invoke("Envio: " + e.Message); }
        }
    }

    private static Task SendFrame(MsnWire board, string text) {
        byte[] data = Encoding.UTF8.GetBytes("MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n" + text);
        if (data.Length > 1664) throw new ArgumentException("Texto excede o limite MSNP7.");
        return board.SendAsync($"MSG {Random.Shared.Next(10, 100000)} A {data.Length}", data);
    }

    public async Task SendAsync(string recipient, string text) {
        if (!Online || _notification == null) throw new InvalidOperationException("Entre na conta antes de enviar.");
        string peer = recipient.ToLowerInvariant();
        if (_switchboards.TryGetValue(peer, out var board))
            await SendFrame(board, text);
        else {
            _queued.GetOrAdd(peer, _ => new()).Enqueue(text);
            if (_opening.TryAdd(peer, 0)) {
                _requests.Enqueue(peer);
                await _notification.SendAsync($"XFR {Interlocked.Increment(ref _tx)} SB");
            }
        }
        MessageReceived?.Invoke(peer, text, true);
    }

    public async Task AddContact(string address) {
        if (_notification == null || !Online) throw new InvalidOperationException("Entre no MSN.");
        address = address.Trim().ToLowerInvariant();
        if (!address.Contains('@') || address == Email) throw new ArgumentException("E-mail de contato inválido.");
        var response = await _notification.RequestAsync($"ADD {Interlocked.Increment(ref _tx)} FL {address} {address}", "ADD");
        if (response.Words.Length < 5 || response.Words[2] != "FL" || response.Words[4] != address)
            throw new InvalidOperationException("O servidor não confirmou o contato.");
        try { await _notification.RequestAsync($"ADD {Interlocked.Increment(ref _tx)} AL {address} {address}", "ADD"); }
        catch { }
        lock (_sync) Ensure(address);
        ContactsChanged?.Invoke();
    }

    public Task SetStatus(string code) =>
        _notification != null && Online ? _notification.SendAsync($"CHG {Interlocked.Increment(ref _tx)} {code}") : Task.CompletedTask;

    public async Task LogoutAsync() {
        _explicitExit = true;
        Online = false;
        if (_notification != null) {
            try { await _notification.SendAsync("OUT"); } catch { }
            await _notification.DisposeAsync(); _notification = null;
        }
        foreach (var board in _switchboards.Values) await board.DisposeAsync();
        _switchboards.Clear(); _queued.Clear(); _opening.Clear();
        lock (_sync) _contacts.Clear();
        ContactsChanged?.Invoke();
    }

    public async ValueTask DisposeAsync() => await LogoutAsync();
}
