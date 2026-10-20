# Animation visual checks

Use a phone with normal system animation speed first. Repeat the checks in light
and dark themes, then with Android's **Remove animations** enabled. Use the
device's equivalent reduced-motion setting if it has a different name. Also
check a narrow screen or increased system font size for clipped controls.

1. **Main navigation:** Rapidly alternate Home, Activity, Budgets, and Portfolio,
   then use Back. Pages should appear immediately without blank flashes, whole-page
   zooms, or elastic icon bounce. Returning to a tab should preserve its period,
   filters, and scroll position.
2. **Dashboard and refresh:** Open Home, immediately pull to refresh, and switch
   away and back. Upcoming content should arrive promptly, without a second
   nested reveal, a late pop, or a restart after data refresh.
3. **Long Upcoming list:** Scroll quickly down a populated Upcoming list and back
   up. Newly visible rows should already be readable, even far down the list;
   there should be no growing blank delay or repeated entrance choreography.
4. **Confirmation and filters:** Open a delete confirmation using a disposable
   item, then Cancel. Cancel and Delete must be visible as soon as the sheet
   itself appears. The icon should settle subtly. Open transaction filters:
   Apply Filters should appear with the sheet and work immediately. Check Back
   and outside-tap dismissal too.
5. **Rapid input:** Type and delete a long amount in Add Transaction. Rename a
   category quickly. Speak a sentence with pauses and corrections in voice entry.
   Only the current digits, name, or transcript should be visible; old values
   should not linger underneath or change the size of the display unexpectedly.
6. **Transaction type colors:** Rapidly alternate Expense, Income, and Transfer,
   including switching again before the prior color finishes changing. Colors
   should continue smoothly from their current appearance, with no abrupt flash
   to an intermediate type's final color. Check fields and fees remain correct.
7. **Portfolio menu and tabs:** Open and dismiss the Portfolio menu repeatedly;
   select each section and swipe between neighboring sections. The menu should
   expand subtly from its top-left trigger without clipping its shadow or text.
   From Home or Analysis, use shortcuts into Activity and Portfolio and check the
   correct section opens.
8. **Savings, budgets, and analysis:** Watch progress bars when opening populated
   screens. Wait at least two seconds: savings bars must not reset and fill a
   second time. Later bars should settle as quickly as earlier bars. Scroll away
   and return, refresh, and update a balance. Percent badges should remain at a
   fixed size. Analysis bars should settle promptly. With many unbudgeted
   categories, Manage should appear alongside the other chips without waiting
   longer as the category count grows.
9. **Account editor and palettes:** Edit an existing account with a selected bank,
   color, and icon near the end of each picker. The correct choice should scroll
   into view promptly. Select colors/icons quickly, apply bank templates, and
   leave during scrolling. There should be no overflow, stuck zoom, or exception.
10. **Savings Coach:** Drag the contribution slider back and forth. Timeline
    markers and displayed estimates should track the input together without a
    trailing animation. Change the deadline and reset. In the stash coach, rapidly
    switch Target Date/Target Amount: the result and controls should transition
    together, with smooth layout resizing and no old controls left clickable.
11. **Android Quick Settings entry:** Launch Koin's quick-entry tile. Navigate
    forward and back through transaction types, amounts, pickers, details,
    recurring income, and success. The window should resize smoothly without
    cutting off content or bouncing. Open/close the note keyboard, rotate the
    device, open the savings-release sheet, drag to dismiss and cancel a short
    drag. Repeat with large text. Confirm saving and draft preservation still work.
12. **Reduced motion and idle:** With Remove animations enabled, repeat palette
    changes, account-editor opening, Portfolio menu selection, and shortcuts into
    Activity. These should have no spatial tween. Start voice recording with
    normal animations, enable Remove animations, and return: the pulse/rings
    should stop while recording continues. Stop recording and verify the app
    settles without a persistent decorative loop. Also enable reduced motion
    during an entrance or quick-entry resize: content must remain visible and
    controls usable.
13. **Categories and transaction history:** Open a long category list, scroll
    quickly to later rows, then back. Rows must appear promptly and remain visible
    when revisited. Open transaction history: rows should have one subtle entrance,
    without a second zoom or heavier fade inside each day group.
14. **Notifications:** Trigger two different validation messages quickly, including
    while the first enters or exits. Only the latest message should remain visible,
    and an earlier timeout must not dismiss it. Enable Remove animations during a
    toast's exit: it must finish disappearing and allow the next message normally.
15. **Form and activity expansion:** Add and remove an end date in a planned
    payment, then expand and collapse an automatic savings-release explanation.
    Content below should resize smoothly without clipping. Repeat rapidly and
    with Remove animations enabled; the final state must remain immediately usable.

For any failure, record the screen, theme, font size, reduced-motion setting,
steps taken, and a short screen recording. A successful checklist checks the
reported motion regressions; physical-device smoothness still depends on hardware
and should be assessed at normal playback speed.
