# Cashback

When adding or editing an expense or transfer, choose the paying account, then
tap **Cashback** inside that account selector. The compact action shows the
current rule and shares the existing account row, leaving category space intact.
Select **None**, **1%**, or **₱5 fixed** in the bottom sheet (the fixed
amount uses your selected currency). Koin calculates cashback from the main
transaction amount, excluding transfer fees, and rounds percentages to centavos.
Eligibility is selected per transaction; Koin does not guess a bank's promotions.

Choosing a cashback rule automatically records a separate income entry under
**Cashback & Rewards** in the source account when the transaction is saved.
The credit uses the transaction date and leaves the full expense unchanged.
Tap **Done** to return to the transaction, then save normally. Quick Entry uses
the same action in the paying account selector during amount entry and review.

The account editor shows total cashback and cashback this month
once the account has cashback activity. Transaction rows show cashback
amounts. Tapping a linked cashback credit opens its original transaction.

Saving the original transaction again updates its existing credit instead of
creating a duplicate. Editing the amount, rule, or account updates the linked
credit too. Selecting None removes cashback. Deleting the original also deletes
its credit. Deleting only the credit clears the original's cashback rule.

Existing transactions default to None. Cashback settings and linked credits are
included in normal database backups.
