# Testing Checklist - Yahya & Co Accounting App

## Pre-Testing Setup
- [ ] Run `flutter pub get` to fetch all dependencies (including image_picker)
- [ ] Verify database migration runs on first app start
- [ ] Create a test business account
- [ ] Verify default accounts created (Cash, Expense, Utilities)

---

## 🧪 Account Management Tests

### Add Account
- [ ] Navigate to Accounts tab
- [ ] Tap add account button
- [ ] Enter account name (required)
- [ ] Select account type (dropdown works)
- [ ] Enter phone number (optional)
- [ ] Enter address (optional)
- [ ] Enter opening balance
- [ ] Tap Save → Success SnackBar appears
- [ ] Account appears in account list

### View Account Detail
- [ ] Tap on account in list
- [ ] Current balance displays correctly (Opening Balance ± transactions)
- [ ] Account avatar shows first letter
- [ ] All fields display correctly (name, type, phone, address, created date)
- [ ] Edit button available when not editing
- [ ] Save button appears when in edit mode

### Edit Account
- [ ] Tap edit button
- [ ] Modify name field (fields become enabled)
- [ ] Change account type from dropdown
- [ ] Update phone and address
- [ ] Modify opening balance
- [ ] Tap Save → Success SnackBar
- [ ] Changes persist (reopen to verify)

### Navigate to Ledger from Account
- [ ] Open account detail
- [ ] Tap "Ledger" button
- [ ] Ledger report opens for that account
- [ ] Transaction history shows correctly

### Navigate to Transactions from Account
- [ ] Open account detail
- [ ] Tap "Transactions" button
- [ ] Transaction list filtered to this business
- [ ] Filters work (Today, Monthly, Expense, Income)

---

## 💳 Transaction Tests

### Add Transaction
- [ ] Navigate to Dashboard → "Add Transaction"
- [ ] Date picker shows current date by default
- [ ] Time picker available
- [ ] Account dropdown populated with all accounts
- [ ] Side selector: ChoiceChip shows Debit/Credit toggle
- [ ] Amount field accepts decimal input
- [ ] Description field accepts text
- [ ] Payment method dropdown works (Cash, Check, Card, Online, Other)
- [ ] Type dropdown works (Expense, Income, Transfer, Other)
- [ ] Image picker button shows image selection dialog
  - [ ] Select image from gallery
  - [ ] Image displays in preview
- [ ] Tap Save → Success SnackBar
- [ ] Transaction saved to database

### Verify Double-Entry Creation
- [ ] Add transaction for Utilities account, Debit 500
- [ ] Check database: journal_entry created with voucher
- [ ] Check database: journal_lines created:
  - [ ] Line 1: Cash account, Credit 500
  - [ ] Line 2: Utilities account, Debit 500
- [ ] Dashboard balance updates immediately

### View Transaction List
- [ ] Navigate to Transactions from Account Detail OR Dashboard
- [ ] All transactions display with amount, date, payment method, type
- [ ] "All" filter shows all transactions
- [ ] "Today" filter shows only today's transactions
- [ ] "Monthly" filter shows only current month
- [ ] "Expense" filter shows only expense account transactions
- [ ] "Income" filter shows only income account transactions
- [ ] Tap transaction → Detail screen opens

### View Transaction Detail
- [ ] All transaction info displays (amount, date, method, type, description)
- [ ] Image displays if attached (full size viewer)
- [ ] Related journal entry info shown (voucher number)
- [ ] Account balance shows for linked account

---

## 📔 Journal Tests

### View Journal List
- [ ] Navigate to Dashboard → "View Journals"
- [ ] All journal entries display with voucher, date, description
- [ ] FAB button available to add new journal
- [ ] Tap journal → Detail screen opens

### Create Journal Entry
- [ ] Tap FAB to create new journal
- [ ] Enter date (validates not empty)
- [ ] Enter description (validates not empty)
- [ ] Add Line button creates new row
- [ ] Each row has: Account ID, Debit, Credit fields
- [ ] Remove button deletes row
- [ ] Multiple rows can be added
- [ ] Tap Save with unbalanced lines → Error: "Debits and Credits must be equal"
- [ ] Balance lines (debit sum = credit sum)
- [ ] Tap Save with balanced lines → Success SnackBar
- [ ] Voucher auto-generated (check DB: JV-1, JV-2, etc.)
- [ ] Journal appears in list

### View Journal Detail
- [ ] Open journal from list
- [ ] Voucher number displays
- [ ] Date displays correctly
- [ ] Description shows
- [ ] All journal lines show with Account ID, Debit, Credit
- [ ] Line items match what was entered

---

## 📊 Reports Tests

### Navigate to Reports
- [ ] Dashboard → BottomNav Reports tab
- [ ] All Reports button visible
- [ ] Tap All Reports → Menu screen opens
- [ ] All report options listed

### Trial Balance Report
- [ ] Tap Trial Balance from Reports menu
- [ ] All accounts display with debit and credit totals
- [ ] Summary row shows total debit and total credit
- [ ] Verify: Total Debit ≈ Total Credit (should match if double-entry correct)
- [ ] Accounts from manual journals appear in list
- [ ] Running balance calculations correct

### Profit & Loss Report
- [ ] Tap P&L from Reports menu
- [ ] Shows Income (credit of Revenue accounts) > 0
- [ ] Shows Expense (debit of Expense accounts) > 0
- [ ] Shows Net Profit = Income - Expense
- [ ] Results based on all journal entries in database

### Ledger Report (Account-Specific)
- [ ] From Account Detail, tap "Ledger" button
- [ ] Transaction history shows for that account
- [ ] Date, voucher, description, debit, credit columns
- [ ] Running balance column shows cumulative balance
- [ ] First entry shows: opening balance + first transaction
- [ ] Subsequent entries show running balance

---

## 📱 Dashboard Tests

### Summary Cards
- [ ] Total Cash card shows correct balance
- [ ] Total Credit card shows sum of all credits
- [ ] Total Debit card shows sum of all debits
- [ ] Total Income card shows revenue credits
- [ ] Total Expense card shows expense debits
- [ ] Numbers update after new transaction

### Quick Action Tiles
- [ ] All 6 tiles visible (Add Transaction, Add Journal, View Journals, Add Account, Ledger, Reports)
- [ ] Each tile taps to correct screen
- [ ] Icons display correctly
- [ ] Titles readable

### Pull-to-Refresh
- [ ] Pull down on dashboard → Refresh spinner
- [ ] Summary cards update with latest data
- [ ] Spinner disappears

### BottomNav
- [ ] 4 tabs available: Home, Reports, Accounts, Calculator
- [ ] Index 0 (Home) shows dashboard
- [ ] Index 1 (Reports) shows reports tab
- [ ] Index 2 (Accounts) navigates to accounts screen
- [ ] Index 3 (Calculator) navigates to calculator
- [ ] Active tab highlight works

---

## 🔒 Validation Tests

### Double-Entry Enforcement
- [ ] Manually create journal with Debit 100 only
- [ ] Try to save → Error message
- [ ] Add Credit 100 line
- [ ] Save succeeds
- [ ] DB shows balanced journal lines

### Account Type Filtering
- [ ] Create expense account "Office Supplies"
- [ ] Create revenue account "Sales"
- [ ] Create transaction for each
- [ ] Filter by Expense → Only Office Supplies transaction shows
- [ ] Filter by Income → Only Sales transaction shows
- [ ] Filter by All → Both show

### Image Attachment
- [ ] Add transaction with image
- [ ] Close transaction detail and reopen
- [ ] Image still displays (persisted to file)

### Date Validation
- [ ] Transaction with future date saves (allowed)
- [ ] Journal with past date saves (allowed)
- [ ] No date field empty validation error (required)

---

## 🔄 Database Persistence Tests

### Restart App
- [ ] Add account, transaction, journal
- [ ] Close app completely
- [ ] Reopen app
- [ ] All data persists in lists
- [ ] Balances calculated correctly

### Database Queries
- [ ] Open Account Detail → Balance loads correctly
- [ ] Open Ledger → Transactions load correctly
- [ ] Open Trial Balance → All accounts load
- [ ] Open P&L → Income/Expense calculated correctly

---

## 🎨 UI/UX Tests

### Loading States
- [ ] FutureBuilder shows CircularProgressIndicator while loading
- [ ] Data displays once loaded
- [ ] Error handling shows if query fails

### SnackBars
- [ ] Success operations show green SnackBar
- [ ] Errors show red SnackBar
- [ ] Validation errors show appropriate message

### Navigation
- [ ] Back button works on all screens
- [ ] FAB buttons accessible and responsive
- [ ] All links between screens work

### Form Fields
- [ ] TextFields accept input correctly
- [ ] Dropdowns expand and select correctly
- [ ] ChoiceChips toggle correctly
- [ ] Number fields accept decimals
- [ ] Date picker shows calendar

---

## 📈 Scale Tests

### Large Dataset
- [ ] Create 100+ transactions
- [ ] Transaction list still responsive
- [ ] Ledger still loads quickly
- [ ] Trial balance calculates without delay

### Multiple Accounts
- [ ] Create 20+ accounts
- [ ] Account dropdown works smoothly
- [ ] Account list displays all

---

## 🔧 Technical Verification

### Compilation
- [ ] `flutter analyze` shows no errors
- [ ] `flutter test` passes (if tests exist)
- [ ] App runs on emulator/device without crash

### Dependencies
- [ ] image_picker package available
- [ ] All imports resolve
- [ ] No runtime dependency errors

### Database
- [ ] SQLite file created on first run
- [ ] Schema tables created correctly
- [ ] Queries execute without error

---

## ✅ Final Sign-Off

- [ ] All test categories completed
- [ ] No critical issues found
- [ ] No compilation warnings
- [ ] App runs smoothly on test device
- [ ] Financial calculations verified
- [ ] Double-entry bookkeeping working correctly
- [ ] All features functional and responsive

---

## 🐛 Bug Report Template

If issues found during testing:

```
Title: [Feature] Issue Description
Severity: Critical | High | Medium | Low
Steps to Reproduce:
1. ...
2. ...
3. ...
Expected Result:
Actual Result:
Screenshots/Logs:
Database State: (relevant account/transaction IDs)
```

---

**Testing Version**: Complete Implementation
**Date**: February 2025
**Tester**: _______________
**Result**: ✅ PASS / ❌ FAIL
