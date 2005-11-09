unit NLDXPSelection;

interface

uses
  Windows, Classes, Messages;

type
  TNLDXPSelection = class(TComponent)
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start(MaxBounds: TRect);
  end;

  TWMXPSelect = packed record
    Msg: Cardinal;
    TopLeft: TSmallPoint;
    BottomRight: TSmallPoint;
    Result: LongInt;
  end;

const
  WM_XPSELECTIONMOVE = WM_APP + 13294;
  WM_XPSELECTIONFINISH = WM_APP + 13295;

procedure Register;

implementation

uses
  Forms, Graphics, Math, Controls, SysUtils;

procedure Register;
begin
  RegisterComponents('NLDelphi', [TNLDXPSelection]);
end;

type
  TXPSelectionControl = class(TCustomControl)
  private
    MaxBounds: TRect;
    procedure WMEraseBkgnd(var Msg: TWmEraseBkgnd); message WM_ERASEBKGND;
    procedure WMPaint(var Msg: TWMPaint); message WM_PAINT;
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

constructor TNLDXPSelection.Create(AOwner: TComponent);
begin
  inherited;
  if AOwner is TCustomForm then
  begin
    Form := TCustomForm(AOwner);
    Control := TXPSelectionControl.Create(Self);
    Control.Parent := Form;
    BackGround := TBitmap.Create;
    ForeGround := TBitmap.Create;
    with ForeGround do
    begin
      Width := Screen.Width;
      Height := Screen.Height;
      Canvas.Brush.Color := clHighLight;
      Canvas.FillRect(Rect(0, 0, Screen.Width, Screen.Height));
    end;
    with BlendFunc do
    begin
      BlendOp := AC_SRC_OVER;
      BlendFlags := 0;
      SourceConstantAlpha := 80;
      AlphaFormat := 0;
    end;
    MemDC := CreateCompatibleDC(Control.Canvas.Handle);
    MemPen := CreatePen(PS_SOLID, 1, ColorToRGB(clHighLight));
    SelectObject(MemDC, MemPen);
  end;
end;

destructor TNLDXPSelection.Destroy;
begin
  if Assigned(Form) then
  begin
    DeleteObject(MemPen);
    DeleteDC(MemDC);
    ForeGround.Free;
    BackGround.Free;
  end;
  inherited;
end;

procedure TNLDXPSelection.Start(MaxBounds: TRect);
begin
  if not Assigned(Form) then
    raise Exception.CreateFmt(
      'XPSelection ''%s'' must be owned by a TCustomForm', [Name])
  else
    if not Control.MouseCapture then
    begin
      P1 := Form.ScreenToClient(Mouse.CursorPos);
      with MaxBounds do
      begin
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
  if Visible then
  begin
    SetBounds(Min(P1.X, P2.X), Min(P1.Y, P2.Y),
              Abs(P1.X - P2.X), Abs(P1.Y - P2.Y));
    Form.Update;
  end;
  PostMessage(Form.Handle, WM_XPSELECTIONMOVE,
    LongInt(PointToSmallPoint(Point(Left, Top))),
    LongInt(PointToSmallPoint(Point(Left + Width, Top + Height))));
end;

procedure TXPSelectionControl.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MouseCapture := False;
  Hide;
  Form.EnableAlign;
  PostMessage(Form.Handle, WM_XPSELECTIONFINISH,
    LongInt(PointToSmallPoint(Point(Left, Top))),
    LongInt(PointToSmallPoint(Point(Left + Width, Top + Height))));
end;

procedure TXPSelectionControl.WMEraseBkgnd(var Msg: TWmEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TXPSelectionControl.WMPaint(var Msg: TWMPaint);
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
    Form.Caption := IntToStr(Canvas.Pixels[1, 1]);
  finally
    DeleteObject(MemBitmap);
  end;
end;

end.
