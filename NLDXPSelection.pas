{ *************************************************************************** }
{                                                                             }
{ NLDXPSelection  -  www.nldelphi.com Open Source designtime component        }
{                                                                             }
{ Initiator: Albert de Weerd (aka NGLN)                                       }
{ License: Free to use, free to modify                                        }
{ Website: http://www.nldelphi.com/forum/showthread.php?t=19564               }
{ SVN path: http://svn.nldelphi.com/nldelphi/opensource/ngln/NLDXPSelection   }
{                                                                             }
{ *************************************************************************** }
{                                                                             }
{ Date: May 17, 2008                                                          }
{ Version: 2.0.0.0                                                            }
{                                                                             }
{ *************************************************************************** }

unit NLDXPSelection;

interface

uses
  Messages, Windows, Graphics, Classes;

const
  DefXPSelColor = clHighLight;
  WM_XPSELECTIONRESIZE = WM_APP + 13294;
  WM_XPSELECTIONFINISH = WM_APP + 13295;

type
  TWMXPSelect = packed record
    Msg: Cardinal;
    TopLeft: TSmallPoint;
    BottomRight: TSmallPoint;
    Unused: LongInt;
  end;

  TXPSelectEvent = procedure(Sender: TObject; const SelRect: TRect) of object;

  TCustomXPSelection = class(TComponent)
  private
    FColor: TColor;
    FOnFinish: TXPSelectEvent;
    FOnResize: TXPSelectEvent;
    FSelectionControl: Pointer;
    procedure SetColor(const Value: TColor);
  protected
    property Color: TColor read FColor write SetColor default DefXPSelColor;
    property OnFinish: TXPSelectEvent read FOnFinish write FOnFinish;
    property OnResize: TXPSelectEvent read FOnResize write FOnResize;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start(const MaxBounds: TRect);
  end;

  TNLDXPSelection = class(TCustomXPSelection)
  published
    property Color;
    property OnFinish;
    property OnResize;
  end;

procedure Register;

implementation

uses
  Controls, Forms, Math;

procedure Register;
begin
  RegisterComponents('NLDelphi', [TNLDXPSelection]);
end;

{ TXPSelectionControl }

type
  TXPSelectionControl = class(TCustomControl)
  private
    FBitmap: TBitmap;
    FBlendFunc: BLENDFUNCTION;
    FFilter: TBitmap;
    FForm: TCustomForm;
    FMaxBounds: TRect;
    FP1: TPoint;
    FP2: TPoint;
    FXPSelection: TCustomXPSelection;
    procedure CMColorChanged(var Message: TMessage); message CM_COLORCHANGED;
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMPaint(var Msg: TWMPaint); message WM_PAINT;
  protected
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X,
      Y: Integer); override;
    procedure RequestAlign; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Init(const MaxBounds: TRect);
  end;

procedure TXPSelectionControl.CMColorChanged(var Message: TMessage);
begin
  FFilter.Canvas.Brush.Color := Color;
  Canvas.Pen.Color := Color;
end;

constructor TXPSelectionControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csCaptureMouse, csOpaque];
  FBitmap := TBitmap.Create;
  FFilter := TBitmap.Create;
  FBlendFunc.BlendOp := AC_SRC_OVER;
  FBlendFunc.SourceConstantAlpha := 80;
  FXPSelection := TCustomXPSelection(AOwner);
  FForm := TCustomForm(FXPSelection.Owner);
  Parent := FForm;
end;

destructor TXPSelectionControl.Destroy;
begin
  FFilter.Free;
  FBitmap.Free;
  inherited Destroy;
end;

procedure TXPSelectionControl.Init(const MaxBounds: TRect);
var
  FormClientRect: TRect;
begin
  if not MouseCapture then
  begin
    FP1 := FForm.ScreenToClient(Mouse.CursorPos);
    FormClientRect := FForm.ClientRect;
    FMaxBounds.Left := Max(MaxBounds.Left, 0);
    FMaxBounds.Top := Max(MaxBounds.Top, 0);
    FMaxBounds.Right := Min(MaxBounds.Right, FormClientRect.Right);
    FMaxBounds.Bottom := Min(MaxBounds.Bottom, FormClientRect.Right);
    FFilter.Width := FormClientRect.Right;
    FFilter.Height := FormClientRect.Bottom;
    FFilter.Canvas.FillRect(FormClientRect);
    FBitmap.Width := FormClientRect.Right;
    FBitmap.Height := FormClientRect.Bottom;
    FBitmap.Canvas.CopyRect(FormClientRect, FForm.Canvas, FormClientRect);
    with FBitmap do
      AlphaBlend(Canvas.Handle, 1, 1, Width - 2, Height - 2,
        FFilter.Canvas.Handle, 0, 0, Width - 3, Height - 3, FBlendFunc);
    BringToFront;
    MouseCapture := True;
  end;
end;

procedure TXPSelectionControl.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  FP2.X := Max(FMaxBounds.Left, Min(Left + X, FMaxBounds.Right));
  FP2.Y := Max(FMaxBounds.Top, Min(Top + Y, FMaxBounds.Bottom));
  if (Abs(FP1.X - FP2.X) > Mouse.DragThreshold) or
    (Abs(FP1.Y - FP2.Y) > Mouse.DragThreshold) then
    Show;
  if Visible then
  begin
    SetBounds(Min(FP1.X, FP2.X), Min(FP1.Y, FP2.Y),
              Abs(FP1.X - FP2.X), Abs(FP1.Y - FP2.Y));
    FForm.Update;
    if Assigned(FXPSelection.FOnResize) then
      FXPSelection.FOnResize(FXPSelection, BoundsRect)
    else
      PostMessage(FForm.Handle, WM_XPSELECTIONRESIZE,
        Integer(PointToSmallPoint(BoundsRect.TopLeft)),
        Integer(PointToSmallPoint(BoundsRect.BottomRight)));
  end;
end;

procedure TXPSelectionControl.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MouseCapture := False;
  if Visible then
  begin
    Hide;
    if Assigned(FXPSelection.FOnFinish) then
      FXPSelection.FOnFinish(FXPSelection, BoundsRect)
    else
      PostMessage(FForm.Handle, WM_XPSELECTIONFINISH,
        Integer(PointToSmallPoint(BoundsRect.TopLeft)),
        Integer(PointToSmallPoint(BoundsRect.BottomRight)));
  end;
end;

procedure TXPSelectionControl.RequestAlign;
begin
  {eat inherited}
end;

procedure TXPSelectionControl.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TXPSelectionControl.WMPaint(var Msg: TWMPaint);
begin
  BitBlt(Canvas.Handle, 1, 1, Width - 2, Height - 2, FBitmap.Canvas.Handle,
    Left + 1, Top + 1, SRCCOPY);
  Canvas.LineTo(0, Height - 1);
  Canvas.LineTo(Width - 1, Height - 1);
  Canvas.LineTo(Width - 1, 0);
  Canvas.LineTo(0, 0);
  Msg.Result := 0;
end;

{ TCustomXPSelection }

const
  SErrInvalidOwnerF = 'XPSelection ''%s'' must be owned by a TCustomForm';

constructor TCustomXPSelection.Create(AOwner: TComponent);
begin
  if AOwner is TCustomForm then
  begin
    inherited Create(AOwner);
    if not (csDesigning in ComponentState) then
      FSelectionControl := TXPSelectionControl.Create(Self);
    SetColor(DefXPSelColor);
  end
  else
    raise EComponentError.CreateFmt(SErrInvalidOwnerF, [Name]);
end;

procedure TCustomXPSelection.SetColor(const Value: TColor);
begin
  if FColor <> Value then
  begin
    if Value = clDefault then
      FColor := DefXPSelColor
    else
      FColor := Value;
    if FSelectionControl <> nil then
      TXPSelectionControl(FSelectionControl).Color := FColor;
  end;
end;

procedure TCustomXPSelection.Start(const MaxBounds: TRect);
begin
  TXPSelectionControl(FSelectionControl).Init(MaxBounds);
end;

end.

