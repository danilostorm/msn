using System.Collections.Generic;
using System.Diagnostics;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;

using System.IO;

namespace StormMSN.Classic;

public partial class MainWindow : Window {
    private readonly MsnSession _session = new();
    private readonly HttpClient _api = new() { Timeout = TimeSpan.FromSeconds(25) };
    private readonly Dictionary<string, ChatWindow> _chats = new(StringComparer.OrdinalIgnoreCase);
    private bool _demo;
    private bool _signingIn;
    private string? _mediaToken;
    private string? _loginEmail;
    private string? _myUsername;
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "StormMSN.Classic", "remembered-email.txt");

    public MainWindow() {
        InitializeComponent();
        try { if (File.Exists(SettingsPath)) EmailInput.Text = File.ReadAllText(SettingsPath).Trim(); }
        catch { }
        _session.ContactsChanged += () => Dispatcher.InvokeAsync(RefreshContacts);
        _session.MessageReceived += (peer, text, mine) => Dispatcher.InvokeAsync(() => {
            if (_chats.TryGetValue(peer, out var chat)) chat.AppendMessage(text, mine);
            else if (!mine) { StatusLine.Text = "Nova mensagem de " + peer; }
        });
        _session.Error += text => Dispatcher.InvokeAsync(() => {
            StatusLine.Text = text;
            MessageBox.Show(this, text, "Storm MSN", MessageBoxButton.OK, MessageBoxImage.Information);
        });
        _session.Disconnected += () => Dispatcher.InvokeAsync(() => {
            StatusLine.Text = "Conexão perdida. Abra Arquivo > Entrar para reconectar.";
        });
        // A visible preview keeps the classic window inspectable without any
        // test accounts, invented online data, or server-side changes.
        if (LoginButton.Parent is StackPanel stack) {
            var demo = new Button {
                Content = "Prévia visual sem conectar",
                FontSize = 11, Foreground = Brushes.SteelBlue, Background = Brushes.Transparent,
                BorderThickness = new Thickness(0), HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 10, 0, 0)
            };
            demo.Click += (_, _) => OpenPreview();
            stack.Children.Add(demo);
        }
        // status is a tiny caption, not a separate persistent banner.
        StatusLine = new TextBlock {
            FontSize = 10, Foreground = Brushes.SlateGray,
            Text = "Cliente Windows paralelo • seu Messenger original não será alterado.",
            Margin = new Thickness(8, 0, 8, 2),
            TextAlignment = TextAlignment.Center
        };
        if (FooterBar is Grid footer) footer.Children.Add(StatusLine);
        ShowLogin();
    }

    private TextBlock StatusLine { get; }
    private void ShowLogin() {
        ContactsLayer.Visibility = Visibility.Collapsed;
        LoginLayer.Visibility = Visibility.Visible;
        SignInOverlay.Visibility = Visibility.Collapsed;
        LoginButton.IsEnabled = true;
        PasswordInput.Password = "";
        LoginError.Text = "";
        MyDisplay.Text = "Meu Messenger";
        StatusLine.Text = "Storm MSN Classic • Windows";
        _demo = false;
    }
    private void ShowContacts() {
        LoginLayer.Visibility = Visibility.Collapsed;
        ContactsLayer.Visibility = Visibility.Visible;
        MyEmail.Text = _loginEmail ?? "";
        MyDisplay.Text = _myUsername ?? (_demo ? "Prévia do Messenger" : _loginEmail ?? "Messenger");
        if (!_demo && _loginEmail != null) {
            TryAvatar(SelfAvatar, _loginEmail);
            TryAvatar(LoginAvatar, _loginEmail);
        }
        RefreshContacts();
        StatusLine.Text = _demo ? "MODO DE DEMONSTRAÇÃO • não conectado" : "Conectado ao Storm MSN";
    }

    private static void TryAvatar(Image target, string address) {
        try {
            target.Source = new BitmapImage(
                new Uri("https://msn.hoststorm.com.br/api/mobile/avatar/" +
                        Uri.EscapeDataString(address)));
        } catch { target.Source = null; }
    }

    private void OpenPreview() {
        _demo = true;
        _loginEmail = "preview@storm-msn.local";
        _myUsername = "Storm MSN • Prévia";
        ShowContacts();
    }

    private async void Login_Click(object sender, RoutedEventArgs e) {
        if (_signingIn) return;
        string id = EmailInput.Text.Trim();
        string pass = PasswordInput.Password;
        if (id.Length == 0 || pass.Length == 0) {
            LoginError.Text = "Informe seu e-mail/usuário e senha.";
            return;
        }
        _signingIn = true;
        LoginButton.IsEnabled = false;
        SignInOverlay.Visibility = Visibility.Visible;
        LoginError.Text = "";
        var spin = new DoubleAnimation(0, 360, TimeSpan.FromMilliseconds(1150)) {
            RepeatBehavior = RepeatBehavior.Forever
        };
        ((RotateTransform)SpinnerPeople.RenderTransform)
            .BeginAnimation(RotateTransform.AngleProperty, spin);
        try {
            var result = await _api.PostAsJsonAsync(
                "https://msn.hoststorm.com.br/api/mobile/session",
                new { identifier = id, password = pass });
            if (!result.IsSuccessStatusCode) {
                throw new InvalidOperationException(result.StatusCode == System.Net.HttpStatusCode.Unauthorized
                    ? "Usuário ou senha incorretos." : "Erro HTTP " + (int)result.StatusCode);
            }
            using var data = JsonDocument.Parse(await result.Content.ReadAsStringAsync());
            string address = data.RootElement.GetProperty("email").GetString()!;
            string user = data.RootElement.GetProperty("username").GetString() ?? address;
            _mediaToken = data.RootElement.GetProperty("token").GetString();
            string code = ((ComboBoxItem)LoginStatus.SelectedItem).Tag.ToString()!;
            await _session.LoginAsync(address, pass, code);
            _loginEmail = address;
            _myUsername = user;
            _demo = false;
            if (RememberEmail.IsChecked == true) {
                Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
                File.WriteAllText(SettingsPath, id);
            } else if (File.Exists(SettingsPath)) File.Delete(SettingsPath);
            PasswordInput.Password = ""; // Never persist the account password.
            ShowContacts();
        } catch (Exception ex) {
            _mediaToken = null;
            LoginError.Text = ex.Message;
        } finally {
            _signingIn = false;
            LoginButton.IsEnabled = true;
            SignInOverlay.Visibility = Visibility.Collapsed;
            ((RotateTransform)SpinnerPeople.RenderTransform)
                .BeginAnimation(RotateTransform.AngleProperty, null);
        }
    }

    private async void CancelLogin_Click(object sender, RoutedEventArgs e) {
        await _session.LogoutAsync();
        SignInOverlay.Visibility = Visibility.Collapsed;
        LoginButton.IsEnabled = true;
        _signingIn = false;
    }

    private void RefreshContacts() {
        if (ContactItems == null) return;
        ContactItems.Children.Clear();
        var all = _demo
            ? new[] {
                new MsnBuddy("amigo.demo@example.invalid", "Amigo do MSN") { Presence = "NLN", Favorite = true },
                new MsnBuddy("contato.demo@example.invalid", "Contato ausente") { Presence = "AWY" },
                new MsnBuddy("outro.demo@example.invalid", "Contato offline") { Presence = "FLN" }
            }
            : _session.Contacts;
        string query = SearchInput?.Text?.Trim() ?? "";
        var people = all.Where(x => x.Name.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                                    x.Email.Contains(query, StringComparison.OrdinalIgnoreCase))
                        .OrderBy(x => x.Name).ToArray();
        var favorites = people.Where(x => x.Favorite).ToArray();
        var online = people.Where(x => x.IsOnline).ToArray();
        var offline = people.Where(x => !x.IsOnline).ToArray();
        AddGroup("★ Favoritos (" + favorites.Length + ")", favorites);
        AddGroup("▸ Grupos (0)", []);
        AddGroup("● Disponível (" + online.Length + ")", online);
        AddGroup("◌ Offline (" + offline.Length + ")", offline);
    }

    private void AddGroup(string label, MsnBuddy[] contacts) {
        var head = new TextBlock {
            Text = label, FontSize = 14, Foreground = new SolidColorBrush(Color.FromRgb(50, 105, 142)),
            Margin = new Thickness(3, 13, 0, 8)
        };
        ContactItems.Children.Add(head);
        if (contacts.Length == 0 && label.StartsWith("★")) {
            ContactItems.Children.Add(new TextBlock {
                Text = "Arraste aqui seus contatos favoritos.", TextWrapping = TextWrapping.Wrap,
                Foreground = Brushes.Gray, FontSize = 11, Margin = new Thickness(15, 0, 0, 7)
            });
        }
        foreach (var buddy in contacts) AddBuddy(buddy);
    }

    private void AddBuddy(MsnBuddy buddy) {
        var row = new Grid { Margin = new Thickness(2, 0, 0, 0) };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(46) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(14) });
        var avatar = new Border {
            Width = 40, Height = 40, CornerRadius = new CornerRadius(5),
            BorderThickness = new Thickness(3), Padding = new Thickness(2),
            BorderBrush = new SolidColorBrush(buddy.IsOnline ? Color.FromRgb(82, 210, 36) : Color.FromRgb(203, 163, 88)),
            Background = Brushes.White
        };
        var inner = new Grid { Background = new SolidColorBrush(Color.FromRgb(179, 218, 238)) };
        inner.Children.Add(new TextBlock {
            Text = "♟", FontSize = 22, Foreground = Brushes.SteelBlue,
            VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center
        });
        if (!_demo) {
            try {
                inner.Children.Add(new Image { Source = new BitmapImage(buddy.Avatar), Stretch = Stretch.UniformToFill });
            } catch { }
        }
        avatar.Child = inner;
        Grid.SetColumn(avatar, 0);
        row.Children.Add(avatar);
        var stack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        stack.Children.Add(new TextBlock {
            Text = buddy.Name, FontSize = 12.5, Foreground = new SolidColorBrush(Color.FromRgb(29, 75, 100)),
            TextTrimming = TextTrimming.CharacterEllipsis, FontWeight = FontWeights.SemiBold
        });
        stack.Children.Add(new TextBlock {
            Text = buddy.StatusName, FontSize = 10.5, Foreground = Brushes.Gray,
            TextTrimming = TextTrimming.CharacterEllipsis
        });
        Grid.SetColumn(stack, 1); row.Children.Add(stack);
        var dot = new TextBlock {
            Text = "●", FontSize = 12, Foreground = buddy.IsOnline ? Brushes.LimeGreen : Brushes.LightGray,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(dot, 2); row.Children.Add(dot);
        var button = new Button {
            Content = row, BorderThickness = new Thickness(0),
            Background = Brushes.Transparent, HorizontalContentAlignment = HorizontalAlignment.Stretch,
            Margin = new Thickness(0, 0, 0, 4), Padding = new Thickness(4), Height = 53
        };
        button.Click += (_, _) => OpenChat(buddy);
        var menu = new ContextMenu();
        var favorite = new MenuItem { Header = buddy.Favorite ? "Remover dos favoritos" : "Adicionar aos favoritos" };
        favorite.Click += (_, _) => { buddy.Favorite = !buddy.Favorite; RefreshContacts(); };
        menu.Items.Add(favorite);
        menu.Items.Add(new MenuItem { Header = "Enviar mensagem", Command = null });
        button.ContextMenu = menu;
        ContactItems.Children.Add(button);
    }

    private void OpenChat(MsnBuddy buddy) {
        if (_chats.TryGetValue(buddy.Email, out var existing)) {
            existing.Activate(); return;
        }
        var conversation = new ChatWindow(this, _session, buddy, UploadMedia, _demo) { Owner = this };
        _chats[buddy.Email] = conversation;
        conversation.Closed += (_, _) => _chats.Remove(buddy.Email);
        conversation.Show();
    }

    private async Task<string> UploadMedia(string filename, byte[] bytes) {
        if (string.IsNullOrEmpty(_mediaToken)) throw new InvalidOperationException("Faça login para enviar arquivos.");
        if (bytes.Length == 0 || bytes.Length > 8 * 1024 * 1024)
            throw new InvalidOperationException("Arquivo vazio ou maior que 8 MB.");
        var safe = new string(filename.Where(x => char.IsAsciiLetterOrDigit(x) || "._()- ".Contains(x)).ToArray());
        if (safe.Length > 100) safe = safe[^100..];
        using var req = new HttpRequestMessage(HttpMethod.Post, "https://msn.hoststorm.com.br/api/mobile/attachment") {
            Content = new ByteArrayContent(bytes)
        };
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _mediaToken);
        req.Headers.Add("X-Storm-Filename", Uri.EscapeDataString(safe));
        req.Content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/octet-stream");
        using var response = await _api.SendAsync(req);
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException("Servidor recusou o anexo (" + (int)response.StatusCode + ").");
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return json.RootElement.GetProperty("url").GetString()!;
    }

    private string? PromptAddress(string title, string hint) {
        var modal = new Window { Owner = this, Title = title, Width = 330, Height = 162,
            WindowStartupLocation = WindowStartupLocation.CenterOwner, ResizeMode = ResizeMode.NoResize };
        var stack = new StackPanel { Margin = new Thickness(14) };
        stack.Children.Add(new TextBlock { Text = hint });
        var box = new TextBox { Margin = new Thickness(0, 10, 0, 8) };
        stack.Children.Add(box);
        string? result = null;
        var button = new Button { Content = "Confirmar", Width = 100, HorizontalAlignment = HorizontalAlignment.Right };
        button.Click += (_, _) => { result = box.Text.Trim(); modal.DialogResult = true; };
        stack.Children.Add(button);
        modal.Content = stack;
        modal.ShowDialog();
        return result;
    }

    private async void AddContact_Click(object sender, RoutedEventArgs e) {
        if (!_session.Online) { MessageBox.Show(this, "Entre na sua conta para adicionar contatos."); return; }
        string? to = PromptAddress("Adicionar contato", "E-mail do contato:");
        if (string.IsNullOrEmpty(to)) return;
        try { await _session.AddContact(to); }
        catch (Exception ex) { MessageBox.Show(this, ex.Message, "Adicionar contato"); }
    }

    private void StartConversation_Click(object sender, RoutedEventArgs e) {
        if (!(_session.Online || _demo)) { MessageBox.Show(this, "Entre no MSN primeiro."); return; }
        var first = _demo ? new MsnBuddy("amigo.demo@example.invalid", "Amigo do MSN") { Presence = "NLN" }
            : _session.Contacts.FirstOrDefault();
        if (first != null) OpenChat(first);
        else MessageBox.Show(this, "Adicione um contato antes de começar a conversar.");
    }

    private async void ContactStatus_Changed(object sender, SelectionChangedEventArgs e) {
        if (_session.Online && ContactStatus.SelectedItem is ComboBoxItem item) {
            try { await _session.SetStatus(item.Tag?.ToString() ?? "NLN"); } catch { }
        }
    }
    private void Search_Changed(object sender, TextChangedEventArgs e) => RefreshContacts();
    private void RefreshContacts_Click(object sender, RoutedEventArgs e) => RefreshContacts();
    private async void SignOut_Click(object sender, RoutedEventArgs e) {
        if (_session.Online) await _session.LogoutAsync();
        _mediaToken = null;
        foreach (var chat in _chats.Values.ToArray()) chat.Close();
        ShowLogin();
    }
    private void ShowLogin_Click(object sender, RoutedEventArgs e) {
        if (_session.Online) { MessageBox.Show(this, "Você já está conectado. Use Arquivo > Sair para trocar de conta."); return; }
        ShowLogin();
    }
    private void TitleDrag(object sender, MouseButtonEventArgs e) { if (e.ChangedButton == MouseButton.Left) DragMove(); }
    private void Minimize_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;
    private void Maximize_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
    private void Close_Click(object sender, RoutedEventArgs e) => Close();
    private void Password_KeyDown(object sender, KeyEventArgs e) { if (e.Key == Key.Enter) Login_Click(sender, e); }
    private void Status_Click(object sender, RoutedEventArgs e) =>
        MessageBox.Show(this, "Altere seu status no menu da sua foto, na lista de contatos.", "Meu status");
    private void Settings_Click(object sender, RoutedEventArgs e) =>
        MessageBox.Show(this, "Esta prévia não grava senhas. Seu e-mail pode ser lembrado localmente.\n" +
            "O Messenger antigo não foi modificado.", "Configurações • Storm MSN");
    private void About_Click(object sender, RoutedEventArgs e) =>
        MessageBox.Show(this, "Storm MSN Classic 0.1 Preview\n" +
            "Cliente Windows paralelo em C# / WPF\nCompatível com servidor Storm MSN MSNP7.\n" +
            "Áudio/vídeo e exclusão sincronizada ainda não implementados.", "Sobre o Storm MSN Classic");
    private static void OpenUrl(string url) {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); } catch { }
    }
    private void Games_Click(object sender, RoutedEventArgs e) =>
        OpenUrl("https://msn.hoststorm.com.br/AppDirectory/Directory.aspx");
    private void Register_Click(object sender, RoutedEventArgs e) =>
        OpenUrl("https://msn.hoststorm.com.br/cadastrar");

    protected override void OnClosed(EventArgs e) {
        foreach (var chat in _chats.Values.ToArray()) chat.Close();
        _ = _session.LogoutAsync();
        _api.Dispose();
        base.OnClosed(e);
    }
}
