import dlangui, dlangui.dialogs.dialog;
import std.typecons;

class InsertASLDialog : Dialog {
  bool firstInsert;

  this(Window parentWindow = null, Flag!"firstInsert" firstInsert = Yes.firstInsert) {
    super(UIString("Insert ASL code"d), parentWindow, DialogFlag.Modal | DialogFlag.Popup);
    this.firstInsert = firstInsert;
  }

  override void initialize() {
    addChild(parseML(import("insertASLDialog.dml")));
  }
}