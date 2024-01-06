using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;
using Windows.Foundation.Collections;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Data;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using System.Net.Sockets;
using System.Net;
using Windows.Media.Protection.PlayReady;
using Windows.Storage.Pickers;
using Windows.Storage.Pickers.Provider;

// The Blank Page item template is documented at https://go.microsoft.com/fwlink/?LinkId=234238

namespace FileTruckerU.Pages
{
	/// <summary>
	/// An empty page that can be used on its own or navigated to within a Frame.
	/// </summary>
	public sealed partial class Receive : Page
	{
        private readonly Socket socket = new(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);

        public Receive()
		{
			this.InitializeComponent();
		}

        private async void OnReceive(object sender, RoutedEventArgs e)
        {
            var picker = new FileSavePicker();

            // Init file picker for Windows
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

            // Add file type choices (required process)
            picker.FileTypeChoices.Add("All files", new List<string>() { "." });

            // Ask save location and get storage file
            StorageFile saveFile = await picker.PickSaveFileAsync();

            if (saveFile != null)
            {
                var ip = IPAddress.Parse(IpAddress.Text);
                var endPoint = new IPEndPoint(ip, 4782);

                // Connect to the server
                await socket.ConnectAsync(endPoint);
                truckerStatus.Text = "Connected.";

                // Get network stream and file stream
                var networkStream = new NetworkStream(socket);
                var fileStream = await saveFile.OpenStreamForWriteAsync();

                // Receive stream and write it to file
                await networkStream.CopyToAsync(fileStream);
                await networkStream.FlushAsync();

                fileStream.Dispose();
                networkStream.Dispose();
                socket.Dispose();

                truckerStatus.Text = "File received.";
            }
            else
            {
                truckerStatus.Text = "Operation cancelled.";
            }
        }
    }
}
