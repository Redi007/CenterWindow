; AutoHotkey v2 script to center windows with smooth animation

#Requires AutoHotkey v2.0

Global g_ignoredWindowClasses := [
  "Shell_TrayWnd",
  "Shell_SecondaryTrayWnd",
  "WorkerW",
  "Progman",
  "SysShadow",
  "Windows.UI.Core.CoreWindow",
]
Global g_ignoredWindowClassSubstrings := ["TaskbarWindow"]
Global g_ignoredWindowTitlesSubstrings := [
  "Rechner",
  "Editor",
  "Einstellungen",
]

Global g_animationDuration := 200
Global g_animationSteps := 20
Global g_stepDelay := g_animationDuration // g_animationSteps

Global g_activeAnimations := Map()
Global g_animationTimer := ""

Global SWP_NOSIZE := 0x0001
Global SWP_NOZORDER := 0x0004
Global SWP_NOACTIVATE := 0x0010
Global SWP_ASYNCWINDOWPOS := 0x4000
Global HWND_TOP := 0

Global MONITOR_DEFAULTTONULL := 0x00000000
Global MONITOR_DEFAULTTOPRIMARY := 0x00000001
Global MONITOR_DEFAULTTONEAREST := 0x00000002

#c::CenterActiveWindow()
#!c::CenterAllWindows()
#+c::CenterActiveWindowOnPrimary()

CenterActiveWindow() {
  try {
    activeHwnd := WinExist("A")
    if !activeHwnd {
      throw Error("Kein aktives Fenster gefunden.")
    }
    monitor := GetNearestMonitorInfo(activeHwnd)
    CenterWindow(activeHwnd, monitor, "Aktives Fenster zentriert")
  } catch Error as err {
    MsgBox(
      "Fehler beim Zentrieren des aktiven Fensters: " err.Message,
      "Fehler",
      "OK IconHand"
    )
  }
}

CenterAllWindows() {
  windowList := WinGetList()
  processedCount := 0
  for thisWindow in windowList {
    if DllCall("IsWindowVisible", "UPtr", thisWindow) && !DllCall(
        "IsIconic",
        "UPtr",
        thisWindow
      ) {
      class := WinGetClass("ahk_id " thisWindow)
      title := WinGetTitle("ahk_id " thisWindow)

      if _IsWindowIgnored(title, class) {
        continue
      }

      try {
        monitor := GetNearestMonitorInfo(thisWindow)
        CenterWindow(thisWindow, monitor)
        processedCount++
      } catch Error {
        continue
      }
    }
  }
  if processedCount > 0 {
    ToolTip(processedCount . " Fenster zentriert")
  } else {
    ToolTip("Keine Fenster zum Zentrieren gefunden/verarbeitet")
  }
  SetTimer(() => ToolTip(), -2000)
}

CenterActiveWindowOnPrimary() {
  try {
    activeHwnd := WinExist("A")
    if !activeHwnd {
      throw Error("Kein aktives Fenster gefunden.")
    }
    primaryMonitor := GetPrimaryMonitorInfo()
    CenterWindow(
      activeHwnd,
      primaryMonitor,
      "Fenster auf primärem Monitor zentriert"
    )
  } catch Error as err {
    MsgBox(
      "Fehler beim Zentrieren des Fensters auf dem primären Monitor: "
        err.Message,
      "Fehler",
      "OK IconHand"
    )
  }
}

CenterWindow(hwnd, targetMonitor, tooltipText := "") {
  Global g_animationDuration
  try {
    WinGetPos(&winX, &winY, &width, &height, "ahk_id " hwnd)

    if width <= 0 || height <= 0 {
      winState := WinGetMinMax("ahk_id " hwnd)
      if winState == -1 {
        WinRestore("ahk_id " hwnd)
        Sleep(150)
        WinGetPos(&winX, &winY, &width, &height, "ahk_id " hwnd)
      }
      if width <= 0 || height <= 0 {
        throw Error("Fenster hat ungültige Abmessungen.")
      }
    }

    newX := targetMonitor.WALeft + (targetMonitor.WAWidth // 2) - (width // 2)
    newY := targetMonitor.WATop + (targetMonitor.WAHeight // 2) - (height // 2)

    if g_animationDuration > 0 {
      AnimateWindowMoveOptimized(hwnd, newX, newY)
    } else {
      SetWindowPosAPI(hwnd, newX, newY)
    }

    if tooltipText != "" {
      ToolTip(tooltipText)
      SetTimer(() => ToolTip(), -1500)
    }
  } catch Error as err {
    throw Error(
      "Fehler beim Zentrieren des Fensters (ID: " hwnd "): " err.Message
    )
  }
}

_IsWindowIgnored(winTitle, winClass) {
  Global g_ignoredWindowClasses, g_ignoredWindowClassSubstrings, g_ignoredWindowTitlesSubstrings
  for ignoredCls in g_ignoredWindowClasses {
    if winClass == ignoredCls {
      return true
    }
  }
  for ignoredSubCls in g_ignoredWindowClassSubstrings {
    if InStr(winClass, ignoredSubCls) {
      return true
    }
  }
  for ignoredSubTitle in g_ignoredWindowTitlesSubstrings {
    if InStr(winTitle, ignoredSubTitle) {
      return true
    }
  }
  return false
}

SetWindowPosAPI(hwnd, x, y) {
  Global SWP_NOSIZE, SWP_NOZORDER, SWP_NOACTIVATE, SWP_ASYNCWINDOWPOS, HWND_TOP
  flags := SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_ASYNCWINDOWPOS
  DllCall("SetWindowPos", "UPtr", hwnd, "UPtr", HWND_TOP, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", flags)
}

AnimateWindowMoveOptimized(hwnd, targetX, targetY) {
  Global g_animationSteps, g_stepDelay
  
  WinGetPos(&startX, &startY, , , "ahk_id " hwnd)
  
  if (Abs(startX - targetX) < 3 && Abs(startY - targetY) < 3) {
    return
  }

  steps := []
  for i in Range(1, g_animationSteps) {
    progress := i / g_animationSteps
    easedProgress := 1 - (1 - progress) ** 2.5
    
    x := Round(startX + (targetX - startX) * easedProgress)
    y := Round(startY + (targetY - startY) * easedProgress)
    steps.Push({x: x, y: y})
  }
  
  steps.Push({x: targetX, y: targetY})
  
  SetTimer(() => _ExecuteAnimationSteps(hwnd, steps, 1), -1)
}

_ExecuteAnimationSteps(hwnd, steps, currentStep) {
  Global g_stepDelay
  
  if currentStep > steps.Length {
    return
  }
  
  step := steps[currentStep]
  SetWindowPosAPI(hwnd, step.x, step.y)
  
  if currentStep < steps.Length {
    SetTimer(() => _ExecuteAnimationSteps(hwnd, steps, currentStep + 1), -g_stepDelay)
  }
}

Range(start, end) {
  arr := []
  Loop end - start + 1 {
    arr.Push(start + A_Index - 1)
  }
  return arr
}

GetNearestMonitorInfo(hwnd) {
  Global MONITOR_DEFAULTTONEAREST
  monitorHandle := DllCall(
    "MonitorFromWindow",
    "UPtr",
    hwnd,
    "UInt",
    MONITOR_DEFAULTTONEAREST,
    "UPtr"
  )
  if !monitorHandle {
    throw Error("Monitor-Handle konnte nicht abgerufen werden.")
  }
  return _GetMonitorInfoByHandle(monitorHandle)
}

GetPrimaryMonitorInfo() {
  Global MONITOR_DEFAULTTOPRIMARY
  hDesktop := DllCall("GetDesktopWindow", "UPtr")
  monitorHandle := DllCall(
    "MonitorFromWindow",
    "UPtr",
    hDesktop,
    "UInt",
    MONITOR_DEFAULTTOPRIMARY,
    "UPtr"
  )
  if !monitorHandle {
    throw Error("Handle des primären Monitors konnte nicht abgerufen werden.")
  }
  return _GetMonitorInfoByHandle(monitorHandle)
}

_GetMonitorInfoByHandle(hMonitor) {
  monitorInfo := Buffer(40, 0)
  NumPut("UInt", 40, monitorInfo, 0)
  if !DllCall("GetMonitorInfo", "UPtr", hMonitor, "Ptr", monitorInfo) {
    throw Error(
      "Monitorinformationen konnten nicht abgerufen werden. Fehlercode: "
        A_LastError
    )
  }
  rcWork := {
    Left: NumGet(monitorInfo, 20, "Int"),
    Top: NumGet(monitorInfo, 24, "Int"),
    Right: NumGet(monitorInfo, 28, "Int"),
    Bottom: NumGet(monitorInfo, 32, "Int"),
  }
  return {
    WALeft: rcWork.Left,
    WATop: rcWork.Top,
    WAWidth: rcWork.Right - rcWork.Left,
    WAHeight: rcWork.Bottom - rcWork.Top,
  }
}
