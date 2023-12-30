using FileTruckerU.Pages;

namespace FileTruckerU;

public sealed partial class MainPage : Page
{
    public MainPage()
    {
        this.InitializeComponent();
    }

    private void NavigationView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.IsSettingsSelected)
        {

        }
        else
        {
            NavigationViewItem item = (NavigationViewItem)args.SelectedItem;

            switch (item.Tag)
            {
                case "Receive":
                    ContentFrame.Navigate(typeof(Receive));
                    break;
                case "Send":
                    ContentFrame.Navigate(typeof(Send));
                    break;
            }
        }   
    }
}
