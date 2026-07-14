using Microsoft.UI.Input;
using Microsoft.UI.Xaml.Controls;

namespace PaperPulse.Windows.Presentation;

public sealed class WorkspaceSplitter : Border
{
    public WorkspaceSplitter()
    {
        ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.SizeWestEast);
    }
}
