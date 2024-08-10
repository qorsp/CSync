#NoEnv
#Warn
SendMode Input
SetWorkingDir %A_ScriptDir%

; Verificar y solicitar permisos de administrador si es necesario
if not A_IsAdmin
{
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

; Variables globales
global capturedX := ""
global capturedY := ""
global automizacionEnCurso := false
global paused := false
global detenerEjecucion := false

; Crear la GUI
Gui, Add, GroupBox, x10 y10 w340 h55, Coordenadas:
Gui, Add, Text, x30 y35 w100, Coordenada X:
Gui, Add, Edit, x110 y32 w56 vCoordX
Gui, Add, UpDown, vUpDownCoordX Range-32768-32767
Gui, Add, Text, x180 y35 w100, Coordenada Y:
Gui, Add, Edit, x260 y32 w70 vCoordY
Gui, Add, UpDown, vUpDownCoordY Range-32768-32767

Gui, Add, Text, x30 y75 w100, Tiempo (ms):
Gui, Add, Edit, x110 y72 w70 vTiempo
Gui, Add, UpDown, vUpDownTiempo Range1-10000
Gui, Add, Text, x200 y75 w100, Repeticiones:
Gui, Add, Edit, x280 y72 w70 vRepeticiones
Gui, Add, UpDown, vUpDownRepeticiones Range1-10000

Gui, Add, Button, x10 y110 w340 h30 gAgregarClic, Agregar Clic
Gui, Add, ListView, x10 y150 w340 h200 vListaClics gListaClicsHandler, Núm.|X|Y|Tiempo (ms)|Repeticiones

Gui, Add, Button, x10 y360 w340 h30 gIniciarAutomatizacion, Iniciar Automatización
Gui, Add, Text, x180 y455 w140 vCoordenadas, X: 0, Y: 0
Gui, Add, Checkbox, x10 y470 vAlwaysOnTop gToggleAlwaysOnTop, Siempre visible
Gui, Add, Button, x10 y400 w170 h30 gEliminarClic, Eliminar Clic Seleccionado
Gui, Add, Button, x180 y400 w170 h30 gLimpiarTodo, Borrar Todos los Clics
Gui, Show, w360 h500, CSync

Gui, Add, Checkbox, x10 y450 w340 vRepetirIndefinidamente, Repetir indefinidamente

; Configurar colores de la ListView
Gui, ListView, ListaClics
LV_ModifyCol(1, "40 Center")
LV_ModifyCol(2, "Center")
LV_ModifyCol(3, "Center")
LV_ModifyCol(4, "Center")
LV_ModifyCol(5, "Center")

SetTimer, ActualizarCoordenadas, 100
return

ValidarNumero:
    if A_GuiEvent = Normal
    {
        GuiControlGet, Contenido,, %A_GuiControl%
        if not RegExMatch(Contenido, "^-?\d*$")
        {
            GuiControl,, %A_GuiControl%, % RegExReplace(Contenido, "[^\d-]")
        }
    }
return

ValidarTiempo:
    if A_GuiEvent = Normal
    {
        GuiControlGet, Contenido,, %A_GuiControl%
        if Contenido is not integer
        {
            Contenido := RegExReplace(Contenido, "[^\d]")
        }
        if (Contenido = "" or Contenido = "0")
        {
            Contenido := 1
        }
        GuiControl,, %A_GuiControl%, %Contenido%
    }
return

ActualizarCoordenadas:
    CoordMode, Mouse, Screen
    MouseGetPos, xpos, ypos
    GuiControl,, Coordenadas, X: %xpos%, Y: %ypos%
return

AgregarClic:
    Gui, Submit, NoHide
    if (CoordX != "" and CoordY != "" and Tiempo != "" and Tiempo >= 1) {
        numClics := LV_GetCount() + 1
        GuiControlGet, repeticiones, , Repeticiones
        LV_Add("", numClics, CoordX, CoordY, Tiempo, repeticiones)
        GuiControl,, CoordX
        GuiControl,, CoordY
        GuiControl,, Tiempo
        GuiControl,, Repeticiones
    }
return

ListaClicsHandler:
    if (A_GuiEvent = "DoubleClick") {
        RowNumber := A_EventInfo
        LV_GetText(SelCoordX, RowNumber, 2)
        LV_GetText(SelCoordY, RowNumber, 3)
        LV_GetText(SelTiempo, RowNumber, 4)
        LV_GetText(SelRepeticiones, RowNumber, 5)
        GuiControl,, CoordX, %SelCoordX%
        GuiControl,, CoordY, %SelCoordY%
        GuiControl,, Tiempo, %SelTiempo%
        GuiControl,, Repeticiones, %SelRepeticiones%
    }
    else if (A_GuiEvent = "RightClick") {
        EliminarClicSeleccionado()
    }
return

EliminarClicSeleccionado() {
    SelectedRows := []
    CurrentRow := 0
    
    ; Recopilar todos los índices de filas seleccionadas
    Loop
    {
        CurrentRow := LV_GetNext(CurrentRow)
        if (CurrentRow = 0)  ; No más filas seleccionadas
            break
        SelectedRows.Push(CurrentRow)
    }
    
    if (SelectedRows.MaxIndex() > 1) {
        MsgBox, 4, Confirmar, ¿Estás seguro de que quieres eliminar SelectedRows.MaxIndex() clics?
        IfMsgBox, No
            return
    } else if (SelectedRows.MaxIndex() = "") {
        ; No hay filas seleccionadas
        return
    }
    
    ; Eliminar las filas seleccionadas en orden inverso
    Loop, % SelectedRows.MaxIndex()
    {
        LV_Delete(SelectedRows[SelectedRows.MaxIndex() - A_Index + 1])
    }
    
    ; Renumerar los clics restantes
    Loop, % LV_GetCount()
    {
        LV_Modify(A_Index, "", A_Index)
    }
}

IniciarAutomatizacion:
    if (automizacionEnCurso) {
        MsgBox, La automatización ya está en curso. Primero detén la automatización actual.
        return
    }
    automizacionEnCurso := true
    detenerEjecucion := false
    Gui, Submit, NoHide
    MsgBox, 4, Confirmar, ¿Estás seguro de iniciar la automatización?
    IfMsgBox, Yes
    {
        filas := LV_GetCount()
        if (filas > 0) {
            CoordMode, Mouse, Screen
            Loop
            {
                if (detenerEjecucion) {
                    automizacionEnCurso := false
                    detenerEjecucion := false
                    MsgBox, Automatización detenida.
                    return
                }
                if (paused) {
                    while (paused)
                        Sleep, 100
                    continue
                }
                
                Loop, %filas%
                {
                    LV_GetText(x, A_Index, 2)
                    LV_GetText(y, A_Index, 3)
                    LV_GetText(tiempo, A_Index, 4)
                    LV_GetText(rep, A_Index, 5)
                    Loop, %rep%
                    {
                        Click, %x%, %y%
                        Sleep, %tiempo%
                    }
                }
                if (!RepetirIndefinidamente)
                    break
            }
            MsgBox, Automatización completada.
        }
        else {
            MsgBox, No hay clics para automatizar.
        }
    }
    automizacionEnCurso := false
return

ToggleAlwaysOnTop:
    Gui, Submit, NoHide
    if (AlwaysOnTop)
        Gui, +AlwaysOnTop
    else
        Gui, -AlwaysOnTop
return

EliminarClic:
    EliminarClicSeleccionado()
return

LimpiarTodo:
    MsgBox, 4, Confirmar, ¿Estás seguro de borrar todos los clics?
    IfMsgBox, Yes
    {
        LV_Delete()
    }
return

GuiClose:
ExitApp

F1::
    CoordMode, Mouse, Screen
    MouseGetPos, capturedX, capturedY
    GuiControl,, CoordX, %capturedX%
    GuiControl,, CoordY, %capturedY%
return

F2::
    paused := !paused
    if (paused)
        ToolTip, Automatización detenida.
    else
        ToolTip
    Sleep, 1000
    ToolTip
return

F3::
    detenerEjecucion := true
    if (automizacionEnCurso)
    {
        MsgBox, Automatización detenida. Presiona el botón "Iniciar Automatización" para comenzar de nuevo.
    }
return

+Delete::
    if (WinActive("CSync")) {
        EliminarClicSeleccionado()
    }
return
