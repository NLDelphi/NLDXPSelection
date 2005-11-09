unit Unit2;

interface

uses
  Windows, Classes, Controls, Forms;

type
  TXPSelection = class(TComponent)
  public
    constructor Create(AOwnerAndParent: TCustomForm); reintroduce;
    destructor Destroy; override;
    procedure Start(MaxBounds: TRect);
  end;

implementation

uses
  Graphics, Math, Messages;

type
  TXPSelectionControl = class(TCustomControl)
  private
    MaxBounds: TRect;
    procedure WMEraseBkgnd(var Message: TWmEraseBkgnd); message WM_ERASEBKGND;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X,
      Y: Integer); override;
  end;

{ TXPSelection }

var
  Form: TCustomForm;
  Control: TXPSelectionControl = nil;
  BackGround: TBitmap;
  ForeGround: TBitmap;
  BlendFunc: BLENDFUNCTION;
  MemDC: HDC;
  MemPen: HPEN;
  P1: TPoint;
  P2: TPoint;

constructor TXPSelection.Create(AOwnerAndParent: TCustomForm);
begin
  inherited Create(AOwnerAndParent);
  Form := AOwnerAndParent;
  Control := TXPSelectionControl.Create(Self);
  Control.Parent := Form;
  BackGround := TBitmap.Create;
  ForeGround := TBitmap.Create;
  with ForeGround do begin
    Width := Screen.Width;
    Height := Screen.Height;
    Canvas.Brush.Color := clHighLight;
    Canvas.FillRect(Rect(0, 0, Screen.Width, Screen.Height));
  end;
  with BlendFunc do begin
    BlendOp := AC_SRC_OVER;
    BlendFlags := 0;
    SourceConstantAlpha := 60;
    AlphaFormat := 0;
  end;
  MemDC := CreateCompatibleDC(Control.Canvas.Handle);
  MemPen := CreatePen(PS_SOLID, 1, ColorToRGB(clHighLight));
  SelectObject(MemDC, MemPen);
end;

destructor TXPSelection.Destroy;
begin
  DeleteObject(MemPen);
  DeleteDC(MemDC);
  ForeGround.Free;
  BackGround.Free;
  inherited;
end;

procedure TXPSelection.Start(MaxBounds: TRect);
begin
  if not Control.MouseCapture then begin
    P1 := Form.ScreenToClient(Mouse.CursorPos);
    with MaxBounds do begin
      Left := Max(Left, 0);
      Top := Max(Top, 0);
      Right := Min(Right, Form.ClientRect.Right);
      Bottom := Min(Bottom, Form.ClientRect.Right);
    end;
    Control.MaxBounds := MaxBounds;
    BackGround.Width := Form.ClientWidth;
    BackGround.Height := Form.ClientHeight;
    BackGround.Canvas.CopyRect(Form.ClientRect, Form.Canvas, Form.ClientRect);
    Control.BringToFront;
    Form.DisableAlign;
    Control.MouseCapture := True;
  end;
end;

{ TXPSelectionControl }

procedure TXPSelectionControl.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  P2 := Form.ScreenToClient(ClientToScreen(Point(X, Y)));
  P2.X := Max(MaxBounds.Left, Min(P2.X, MaxBounds.Right));
  P2.Y := Max(MaxBounds.Top, Min(P2.Y, MaxBounds.Bottom));
  if (Abs(P1.X - P2.X) > Mouse.DragThreshold) or
    (Abs(P1.Y - P2.Y) > Mouse.DragThreshold) then
      Show;
  if Visible then begin
    SetBounds(Min(P1.X, P2.X), Min(P1.Y, P2.Y),
              Abs(P1.X - P2.X), Abs(P1.Y - P2.Y));
    Form.Update;
  end;
end;

procedure TXPSelectionControl.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MouseCapture := False;
  Hide;
  Form.EnableAlign;
end;

procedure TXPSelectionControl.WMEraseBkgnd(var Message: TWmEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TXPSelectionControl.WMPaint(var Message: TWMPaint);
var
  MemBitmap: HBITMAP;
begin
  MemBitmap := CreateCompatibleBitmap(Canvas.Handle, Width, Height);
  SelectObject(MemDC, MemBitmap);
  try
    LineTo(MemDC, 0, Height - 1);
    LineTo(MemDC, Width - 1, Height - 1);
    LineTo(MemDC, Width - 1, 0);
    LineTo(MemDC, 0, 0);
    BitBlt(MemDC, 1, 1, Width - 2, Height - 2,
      BackGround.Canvas.Handle, Left + 1, Top + 1,
      SRCCOPY);
    AlphaBlend(MemDC, 1, 1, Width - 2, Height - 2,
      ForeGround.Canvas.Handle, 0, 0, Width - 2, Height - 2,
      BlendFunc);
    BitBlt(Canvas.Handle, 0, 0, Width, Height, MemDC, 0, 0, SRCCOPY);
  finally
    DeleteObject(MemBitmap);
  end;
end;

end.
