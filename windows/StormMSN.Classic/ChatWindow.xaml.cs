using Microsoft.Win32;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace StormMSN.Classic;

public partial class ChatWindow : Window {
    private readonly MsnSession _session;
    private readonly MsnBuddy _buddy;
    private readonly Func<string, byte[], Task<string>> _upload;
    private readonly bool _demo;
    private readonly MediaPlayer _audio = new();
    private readonly string _photoPrefix = "https://msn.hoststorm.com.br/api/mobile/attachment/";
    private static readonly Regex AttachmentKey = new(@"^[a-f0-9]{48}$", RegexOptions.Compiled);

    public ChatWindow(MainWindow parent, MsnSession session, MsnBuddy buddy,
        Func<string, byte[], Task<string>> upload, bool demo) {
        InitializeComponent();
        _session = session;
        _buddy = buddy;
        _upload = upload;
        _demo = demo;
        PeerName.Text = buddy.Name;
        PeerEmail.Text = buddy.Email;
        PeerStatus.Text = demo ? "Prévia visual — sem conexão" : buddy.StatusName;
        Title = buddy.Name + " — Storm MSN";
        ChatMode.Text = demo ? "PRÉVIA • mensagens não são enviadas" : "Storm MSN • MSNP7";
        if (!demo) {
            try { PeerAvatar.Source = new BitmapImage(buddy.Avatar); }
            catch { }
            if (!string.IsNullOrWhiteSpace(session.Email)) {
                try {
                    var address = Uri.EscapeDataString(session.Email);
                    MyAvatar.Source = new BitmapImage(
                        new Uri("https://msn.hoststorm.com.br/api/mobile/avatar/" + address));
                } catch { }
            }
        }
        AppendInfo(demo
            ? "Prévia de conversa • nenhum contato real conectado."
            : "Conversa com " + buddy.Name + ". Mensagens compatíveis com MSNP7.");
    }

    private void AppendInfo(string content) {
        HistoryItems.Children.Add(new TextBlock {
            Text = content,
            TextWrapping = TextWrapping.Wrap, Foreground = Brushes.Gray,
            FontSize = 11, FontStyle = FontStyles.Italic,
            Margin = new Thickness(2, 4, 2, 12)
        });
    }

    public void AppendMessage(string text, bool mine) {
        var wrapper = new Border {
            Padding = new Thickness(7, 6, 7, 7),
            Margin = new Thickness(0, 0, 0, 8),
            BorderBrush = new SolidColorBrush(Color.FromRgb(225, 237, 244)),
            BorderThickness = new Thickness(0, 0, 0, 1),
            Background = mine ? new SolidColorBrush(Color.FromRgb(245, 251, 254)) : Brushes.White
        };
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock {
            Text = $"{(mine ? "Você" : _buddy.Name)} diz ({DateTime.Now:HH:mm}):",
            Foreground = new SolidColorBrush(Color.FromRgb(15, 107, 166)),
            FontSize = 12.5, FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 6)
        });
        if (TryMedia(text, out string? type, out Uri? url, out string? filename)) {
            if (type == "image") {
                var image = new Image {
                    Source = new BitmapImage(url!), MaxWidth = 290, MaxHeight = 245,
                    Stretch = Stretch.Uniform, HorizontalAlignment = HorizontalAlignment.Left,
                    ToolTip = "Clique para ampliar"
                };
                image.MouseLeftButtonUp += (_, _) => ShowPhoto(url!);
                stack.Children.Add(image);
            } else {
                var card = new Button {
                    Content = (type == "audio" ? "▶  Ouvir mensagem de voz" : "▤  Baixar " + filename),
                    HorizontalAlignment = HorizontalAlignment.Left,
                    BorderBrush = new SolidColorBrush(Color.FromRgb(95, 163, 194)),
                    Background = new SolidColorBrush(Color.FromRgb(230, 247, 254)),
                    Margin = new Thickness(0, 4, 0, 4)
                };
                card.Click += (_, _) => {
                    if (type == "audio") PlayAudio(url!);
                    else OpenBrowser(url!);
                };
                stack.Children.Add(card);
            }
        } else {
            stack.Children.Add(new TextBlock {
                Text = text, FontSize = 12.5, Foreground = Brushes.Black,
                TextWrapping = TextWrapping.Wrap
            });
        }
        wrapper.Child = stack;
        var menu = new ContextMenu();
        var reply = new MenuItem { Header = "Responder" };
        reply.Click += (_, _) => {
            string preview = text.Replace("\r", " ").Replace("\n", " ");
            Compose.Text = "↪ " + (mine ? "Você" : _buddy.Name) + ": " +
                (preview.Length > 90 ? preview[..90] : preview) + "\n" + Compose.Text;
            Compose.Focus();
            Compose.CaretIndex = Compose.Text.Length;
        };
        menu.Items.Add(reply);
        var copy = new MenuItem { Header = "Copiar mensagem" };
        copy.Click += (_, _) => Clipboard.SetText(text);
        menu.Items.Add(copy);
        var delete = new MenuItem { Header = "Apagar somente nesta janela" };
        delete.Click += (_, _) => HistoryItems.Children.Remove(wrapper);
        menu.Items.Add(delete);
        wrapper.ContextMenu = menu;
        HistoryItems.Children.Add(wrapper);
        Dispatcher.BeginInvoke(() => HistoryScroller.ScrollToEnd());
    }

    private bool TryMedia(string text, out string? kind, out Uri? url, out string? filename) {
        kind = null; url = null; filename = null;
        string raw;
        if (text.StartsWith("📷 Foto: ", StringComparison.Ordinal)) {
            kind = "image"; raw = text["📷 Foto: ".Length..].Trim();
        } else if (text.StartsWith("🎤 Mensagem de voz: ", StringComparison.Ordinal)) {
            kind = "audio"; raw = text["🎤 Mensagem de voz: ".Length..].Trim();
        } else if (text.StartsWith("📎 Arquivo: ", StringComparison.Ordinal)) {
            var match = Regex.Match(text, @"^📎 Arquivo: (.+?) (https://\S+)$");
            if (!match.Success) return false;
            kind = "file"; filename = match.Groups[1].Value; raw = match.Groups[2].Value;
        } else return false;
        if (!Uri.TryCreate(raw, UriKind.Absolute, out url) ||
            url.Scheme != Uri.UriSchemeHttps || url.Host != "msn.hoststorm.com.br" ||
            url.Query.Length > 0 || url.Fragment.Length > 0) return false;
        var segments = url.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (segments.Length != 4 || segments[0] != "api" || segments[1] != "mobile" ||
            (kind == "audio" ? segments[2] != "voice" : segments[2] != "attachment") ||
            !AttachmentKey.IsMatch(segments[3])) return false;
        return true;
    }

    private void ShowPhoto(Uri url) {
        var popup = new Window {
            Title = "Visualizar foto • Storm MSN",
            Owner = this, Width = 670, Height = 520, MinWidth = 360, MinHeight = 320,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Background = new SolidColorBrush(Color.FromRgb(20, 31, 44))
        };
        var viewer = new ScrollViewer {
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Content = new Image { Source = new BitmapImage(url), Stretch = Stretch.Uniform }
        };
        popup.Content = viewer;
        popup.ShowDialog();
    }

    private void PlayAudio(Uri url) {
        try {
            _audio.Stop();
            _audio.Open(url);
            _audio.Play();
        } catch {
            OpenBrowser(url);
        }
    }

    private static void OpenBrowser(Uri uri) {
        try { Process.Start(new ProcessStartInfo(uri.AbsoluteUri) { UseShellExecute = true }); }
        catch { }
    }

    private async void Send_Click(object sender, RoutedEventArgs e) => await SendCurrent();
    private async Task SendCurrent() {
        string text = Compose.Text.Trim();
        if (text.Length == 0) return;
        if (text.Length > 1500) {
            MessageBox.Show(this, "A mensagem ultrapassa o limite do MSN.", "Storm MSN");
            return;
        }
        SendButton.IsEnabled = false;
        try {
            if (_demo) AppendMessage(text, true);
            else await _session.SendAsync(_buddy.Email, text);
            Compose.Clear();
        } catch (Exception ex) {
            MessageBox.Show(this, ex.Message, "Não foi possível enviar", MessageBoxButton.OK,
                MessageBoxImage.Warning);
        } finally {
            SendButton.IsEnabled = true;
            Compose.Focus();
        }
    }

    private void Compose_KeyDown(object sender, KeyEventArgs e) {
        if (e.Key == Key.Enter && (Keyboard.Modifiers & ModifierKeys.Shift) == 0) {
            e.Handled = true;
            _ = SendCurrent();
        }
    }

    private async void Photo_Click(object sender, RoutedEventArgs e) => await Attach(true);
    private async void File_Click(object sender, RoutedEventArgs e) => await Attach(false);

    private async Task Attach(bool isPhoto) {
        if (_demo) {
            MessageBox.Show(this, "No modo de prévia, anexos não são enviados ao servidor.");
            return;
        }
        var dialog = new OpenFileDialog {
            Filter = isPhoto
                ? "Imagens|*.png;*.jpg;*.jpeg;*.webp;*.gif|Todas as imagens|*.*"
                : "Arquivos permitidos|*.png;*.jpg;*.jpeg;*.webp;*.gif;*.pdf;*.txt;*.zip;*.docx;*.xlsx",
            Multiselect = false, Title = isPhoto ? "Enviar foto" : "Enviar arquivo"
        };
        if (dialog.ShowDialog(this) != true) return;
        try {
            var info = new FileInfo(dialog.FileName);
            if (info.Length > 8 * 1024 * 1024 && !isPhoto)
                throw new InvalidOperationException("Arquivo acima de 8 MB.");
            byte[] content;
            string filename;
            if (isPhoto) {
                // The desktop encoder creates a JPEG even when the selected
                // photo was HEIF/PNG, preserving compatibility with mobile.
                var image = new BitmapImage();
                image.BeginInit();
                image.UriSource = new Uri(info.FullName);
                image.DecodePixelWidth = 1280;
                image.CacheOption = BitmapCacheOption.OnLoad;
                image.EndInit();
                image.Freeze();
                var encoder = new JpegBitmapEncoder { QualityLevel = 82 };
                encoder.Frames.Add(BitmapFrame.Create(image));
                using var memory = new MemoryStream();
                encoder.Save(memory);
                content = memory.ToArray();
                filename = "foto-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".jpg";
            } else {
                content = await File.ReadAllBytesAsync(info.FullName);
                filename = info.Name;
            }
            if (content.Length > 8 * 1024 * 1024)
                throw new InvalidOperationException("Anexo após conversão excede 8 MB.");
            if (isPhoto) {
                var answer = MessageBox.Show(this,
                    $"Enviar a foto {info.Name} para {_buddy.Name}?",
                    "Confirmar envio", MessageBoxButton.YesNo, MessageBoxImage.Question);
                if (answer != MessageBoxResult.Yes) return;
            }
            string url = await _upload(filename, content);
            await _session.SendAsync(_buddy.Email, isPhoto
                ? "📷 Foto: " + url
                : "📎 Arquivo: " + filename + " " + url);
        } catch (Exception ex) {
            MessageBox.Show(this, ex.Message, "Erro ao enviar anexo",
                MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    private void Emoji_Click(object sender, RoutedEventArgs e) {
        Compose.SelectedText = " :) ";
        Compose.Focus();
    }
    private void Call_Click(object sender, RoutedEventArgs e) =>
        MessageBox.Show(this, "Chamadas de voz/vídeo ainda não estão implementadas neste cliente paralelo.\n" +
            "O Messenger antigo permanece disponível.", "Storm MSN Classic");
    private void Help_Click(object sender, RoutedEventArgs e) =>
        MessageBox.Show(this,
            "Mensagens e contatos: MSNP7 do Storm MSN.\nFotos e arquivos: links HTTPS compatíveis com o Android.\n" +
            "Remoção nesta janela não apaga do outro aparelho.",
            "Sobre esta conversa");
    private void Close_Click(object sender, RoutedEventArgs e) => Close();
    protected override void OnClosed(EventArgs e) {
        _audio.Close();
        base.OnClosed(e);
    }
}
