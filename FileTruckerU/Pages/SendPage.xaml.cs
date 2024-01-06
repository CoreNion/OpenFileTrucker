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
using Windows.Storage.Pickers;
using System.Net.Sockets;
using Microsoft.UI;
using System.Net;
using System.Text;

// The Blank Page item template is documented at https://go.microsoft.com/fwlink/?LinkId=234238

namespace FileTruckerU.Pages
{
	/// <summary>
	/// An empty page that can be used on its own or navigated to within a Frame.
	/// </summary>
	public sealed partial class Send : Page
	{
		public Send()
		{
			this.InitializeComponent();
		}

        private List<StorageFile> files = [];

        private Task serverTask;
        private readonly Socket socket = new(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);

        private async void PickFiles(object sender, RoutedEventArgs e)
        {
            var picker = new FileOpenPicker();

            // Init file picker for Windows
            var hWnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hWnd);

            picker.FileTypeFilter.Add("*");
            var storageFiles = await picker.PickMultipleFilesAsync();

            if (storageFiles != null && storageFiles.Any())
            {
                FileNames.Text = "";
                foreach (var file in storageFiles)
                {
                    FileNames.Text += (file.Name + Environment.NewLine );
                    files.Add(file);
                }
            }
            else
            {
                FileNames.Text = "No files selected";
            }
        }

        async private void StartServer(object sender, RoutedEventArgs e)
        {
            // Start socket server
            socket.Bind(new IPEndPoint(IPAddress.Any, 4782));
            socket.Listen();

            serverTask = Task.Run(() => TruckerServerService());

            ServerStatus.Text = "Server started";
        }

        async private void TruckerServerService()
        {
            // Wait for connection
            var handler = await socket.AcceptAsync();
            Console.WriteLine("Server started");

            // Get NetworkStream and fileStream
            var networkStream = new NetworkStream(handler);
            var fileStream = await files[0].OpenStreamForReadAsync();

            // Flow fileStream to networkStream
            await fileStream.CopyToAsync(networkStream);

            handler.Shutdown(SocketShutdown.Both);
        }
    }
}
