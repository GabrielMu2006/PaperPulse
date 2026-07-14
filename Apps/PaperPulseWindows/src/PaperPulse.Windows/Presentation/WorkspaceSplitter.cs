using Microsoft.UI.Input;
using Microsoft.UI.Xaml.Controls;

namespace PaperPulse.Windows.Presentation;

public sealed class WorkspaceSplitter : ContentControl
{
    public WorkspaceSplitter()
    {
        ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.SizeWestEast);
    }
}
