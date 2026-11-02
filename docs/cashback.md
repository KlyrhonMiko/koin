# Cashback

When adding or editing an expense or transfer, choose the paying account, then
tap **Cashback** inside that account selector. The compact action shows the
current rule and shares the existing account row, leaving category space intact.
Select **None**, **1%**, or **₱5 fixed** in the bottom sheet (the fixed
amount uses your selected currency). Koin calculates cashback from the main
transaction amount, excluding transfer fees, and rounds percentages to centavos.
Each account remembers the last rule you choose, including None. The choice is
saved when you select it, so choosing that account on a new expense or transfer
automatically restores its rule. Switching the paying account loads that
account's own choice. Existing transactions keep their recorded rule when opened
for editing. You can change the rule for any transaction; Koin does not guess a
bank's promotions.

In the account editor's **Cashback → Cashback timing**, choose **Instant** (the
default) or **Delayed**. This default applies when adding cashback; changing it does not
alter cashback already recorded on a transaction.

For Instant accounts, choosing a cashback rule records a separate income entry
under **Cashback & Rewards** in the source account when the transaction is saved.
The credit uses the transaction date and leaves the full expense unchanged.
For Delayed accounts, cashback stays **Pending** and is excluded from balances
and income. In the transaction editor, open **Cashback**, choose the actual
**Receipt date** (today by default), and tap **Mark received**. Receipt dates
must be between the transaction date and today. The income entry is created
on that date when you save the transaction; unsaved changes do not credit money.
To undo receipt, open **Cashback** and tap **Mark pending**, then save. This
clears the receipt date and removes the linked income credit while keeping the
cashback rule and expected amount.
Tap **Done** to return to the transaction, then save normally. Quick Entry uses
the same action in the paying account selector during amount entry and review.

The account editor shows separate **Received** and **Pending** totals once the
account has cashback activity. Transaction rows show cashback amounts with
**pending** or **received** status. Tapping a linked cashback credit opens its
original transaction.
In **Transactions → Filters**, select **Pending cashback** and apply to show
only expenses and transfers with cashback still awaiting receipt. It combines
with the other filters and sort options. Marking cashback received and saving
removes that transaction from the pending results. **Reset All** clears it.

Saving the original transaction again updates its existing credit instead of
creating a duplicate. Editing the amount, rule, or account updates the linked
credit too. Selecting None removes cashback. Deleting the original also deletes
its credit. Deleting only the credit clears the original's cashback rule.

Existing transactions without cashback default to None. Existing cashback
credits remain received after upgrading, preserving balances. Account timing,
remembered rules, pending status, receipt dates, and linked credits are included
in normal database backups.
