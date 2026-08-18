/// Whether leaving Mark as Delivered / Cancel without submitting should
/// clock the driver back Out.
///
/// Clock-in from the overlay is an explicit In. Back must not undo it —
/// that is what made Home show Out and opened the overlay again.
bool shouldRevertClockInOnLeaveFinish({
  required bool openedFromClockedOut,
  required bool completed,
}) {
  // Named args document the QA cases; none of them revert duty.
  return switch ((openedFromClockedOut, completed)) {
    (_, _) => false,
  };
}
