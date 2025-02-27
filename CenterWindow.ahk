; AutoHotkey v2 script to center windows on their respective monitors

; Hotkeys
#c::CenterActiveWindow()      ; Win + C centers the active window
#!c::CenterAllWindows()       ; Win + Alt + C centers all windows

; Centers the active window on its nearest monitor
CenterActiveWindow() {
    try {
        activeHwnd := WinExist("A")  ; Get the handle of the active window
        if !activeHwnd
            throw Error("No active window found.")
        
        CenterWindow(activeHwnd)     ; Center the active window
    } catch Error as err {
        MsgBox("Error centering active window: " err.Message)
    }
}

; Centers all visible, non-minimized windows on their respective monitors, excluding the taskbar
CenterAllWindows() {
    windowList := WinGetList()  ; Get a list of all windows
    for thisWindow in windowList {
        ; Check if the window is visible and not minimized
        if DllCall("IsWindowVisible", "Ptr", thisWindow) && !DllCall("IsIconic", "Ptr", thisWindow) {
            ; Get the window's class name
            class := WinGetClass("ahk_id " thisWindow)
            ; Skip the taskbar and related windows
            if (class != "Shell_TrayWnd" && class != "Shell_SecondaryTrayWnd" && !InStr(class, "TaskbarWindow")) {
                try {
                    CenterWindow(thisWindow)  ; Center this window
                } catch Error {
                    ; Silently skip errors for individual windows
                    continue
                }
            }
        }
    }
}

; Helper function to center a single window on its nearest monitor
CenterWindow(hwnd) {
    try {
        WinGetPos(&winX, &winY, &width, &height, "ahk_id " hwnd)  ; Get the window's width and height
        monitor := GetNearestMonitorInfo(hwnd)  ; Get monitor info
        ; Calculate new position to center the window in the monitor's work area
        newX := monitor.WALeft + (monitor.WAWidth // 2) - (width // 2)
        newY := monitor.WATop + (monitor.WAHeight // 2) - (height // 2)
        WinMove(newX, newY, , , "ahk_id " hwnd)  ; Move the window to the new position
    } catch Error as err {
        throw Error("Failed to center window: " err.Message)
    }
}

; Retrieves monitor information for the nearest monitor to the window
GetNearestMonitorInfo(hwnd) {
    static MONITOR_DEFAULTTONEAREST := 0x00000002  ; Flag to get the nearest monitor
    ; Get the handle of the nearest monitor
    monitorHandle := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", MONITOR_DEFAULTTONEAREST, "Ptr")
    if !monitorHandle
        throw Error("Failed to get monitor handle.")
    
    ; Allocate buffer for MONITORINFO structure (size 40 bytes)
    monitorInfo := Buffer(40, 0)
    NumPut("UInt", 40, monitorInfo, 0)  ; Set cbSize field
    ; Get monitor information
    if !DllCall("GetMonitorInfo", "Ptr", monitorHandle, "Ptr", monitorInfo)
        throw Error("Failed to get monitor info: " A_LastError)
    
    ; Extract monitor information from the buffer
    rcMonitor := {
        Left: NumGet(monitorInfo, 4, "Int"),
        Top: NumGet(monitorInfo, 8, "Int"),
        Right: NumGet(monitorInfo, 12, "Int"),
        Bottom: NumGet(monitorInfo, 16, "Int")
    }
    
    rcWork := {
        Left: NumGet(monitorInfo, 20, "Int"),
        Top: NumGet(monitorInfo, 24, "Int"),
        Right: NumGet(monitorInfo, 28, "Int"),
        Bottom: NumGet(monitorInfo, 32, "Int")
    }
    
    isPrimary := NumGet(monitorInfo, 36, "UInt") & 1
    
    ; Return an object with monitor details
    return {
        Handle: monitorHandle,
        Left: rcMonitor.Left,
        Top: rcMonitor.Top,
        Right: rcMonitor.Right,
        Bottom: rcMonitor.Bottom,
        Width: rcMonitor.Right - rcMonitor.Left,
        Height: rcMonitor.Bottom - rcMonitor.Top,
        WALeft: rcWork.Left,
        WATop: rcWork.Top,
        WARight: rcWork.Right,
        WABottom: rcWork.Bottom,
        WAWidth: rcWork.Right - rcWork.Left,
        WAHeight: rcWork.Bottom - rcWork.Top,
        IsPrimary: isPrimary
    }
}
