# Yahya & Co App - Complete Features Implementation Guide

## Overview
This guide documents all the accounting features now implemented in the Yahya & Co app, including Transactions, Journals, Ledgers, Accounts, and Reports.

---

## 1. Core Architecture

### Database (SQLite via sqflite)
- **Tables**: accounts, transactions, journal_entry, journal_lines, users, business, etc.
- **DatabaseHelper** (`lib/db/database_helper.dart`): Central DB operations with CRUD methods
- **Location**: `lib/db/database_helper.dart`

### Services Layer
- **AccountingService** (`lib/services/accounting_service.dart`): Financial calculations (balances, trial balance, P&L, etc.)
- **AccountService** (`lib/services/account_service.dart`): Account CRUD operations
- **TransactionService** (`lib/services/transaction_service.dart`): Transaction CRUD
- **JournalService** (`lib/services/journal_service.dart`): Journal entry/line management
- **BusinessService** (`lib/services/business_service.dart`): Business data management

### Data Models
All models located in `lib/models/`:
- `account_model.dart`: Account (ID, name, type, phone, address, balance)
- `transaction_model.dart`: Transaction (date, amount, payment method, account, type, image URL)
- `journal_entry_model.dart`: Journal entry (voucher no, date, description)
- `journal_line_model.dart`: Journal line (account, debit, credit)

---

## 2. Dashboard (Home Screen)

**File**: `lib/screens/dashboard/dashboard_screen.dart`

### Features
- **Summary Cards**: Total Cash, Total Credit, Total Debit, Total Income, Total Expense
- **Action Tiles**: Quick access to Add Transaction, Add Journal, Add Account, Ledger
- **Reports Tab**: Links to Trial Balance, Profit & Loss, Balance Sheet, etc.
- **Refresh**: Pull-to-refresh to update dashboard summary

### Navigation
- **Reports**: BottomNav index 1 → displays all reports
- **Accounts**: BottomNav index 2 → opens account list
- **Calculator**: BottomNav index 3 → calculator app

---

## 3. Accounts Management

### Account List Screen
**File**: `lib/screens/accounts/account_screen.dart`
- Displays all accounts for a business
- Create, view, edit account details
- Shows account type and balance

### Add Account Screen
**File**: `lib/screens/accounts/add_account_screen.dart`
- **Fields**: Name, Type (Asset/Liability/Equity/Revenue/Expense/Customer/Supplier/Cash/Bank), Phone, Address, Opening Balance
- **Types**: Dropdown selection of account types
- **Validation**: Requires account name and type
- **Success/Error**: SnackBar feedback

### Account Detail Screen
**File**: `lib/screens/accounts/account_detail_screen.dart`
- **Balance Display**: Shows current balance (from DB calculations)
- **Avatar**: Account name initial in circle
- **Buttons**: "Ledger" (view ledger for this account), "Transactions" (view related transactions)
- **Editable Fields**: Name, Type, Phone, Address, Opening Balance (tap edit icon to modify)
- **Created Date**: Display-only field

---

## 4. Transactions

### Add Transaction Screen
**File**: `lib/screens/transactions/add_transaction_screen.dart`

#### Features
- **Date & Time**: Datepicker and time picker for transaction datetime
- **Account Selection**: Dropdown to select account
- **Side Selection**: ChoiceChip to select Debit or Credit side
- **Amount**: Input field for transaction amount
- **Description**: Text field for notes
- **Image Attachment**: Image picker to attach receipt/document
- **Payment Method**: Dropdown (Cash, Check, Card, Online, Other)
- **Type**: Dropdown (Expense, Income, Transfer, Other)
- **Double-Entry**: Automatically creates journal entry with Cash account (looked up from DB) and user-selected account
- **Validation**: Debits equal credits enforced

#### Save Flow
1. Collect form data
2. Look up cash account ID from DB
3. Create TransactionModel
4. Create journal_entry with transaction details
5. Create journal_lines for cash account (debit or credit) and user account (opposite side)
6. Persist to DB and show success SnackBar

### Transaction List Screen
**File**: `lib/screens/transactions/transaction_list_screen.dart`

#### Features
- **Filters**: All, Today, Monthly, Expense, Income
  - Today: transactions from current date
  - Monthly: transactions from current month
  - Expense: transactions linked to Expense-type accounts
  - Income: transactions linked to Revenue/Income-type accounts
- **List Display**: Shows amount, payment method, date, type
- **Tap to View**: Opens transaction detail

### Transaction Detail Screen
**File**: `lib/screens/transactions/transaction_detail_screen.dart`

#### Display
- **Transaction Info**: Amount, date, payment method, type, description
- **Image Viewer**: If image attached, displays receipt/document
- **Related Journal**: Shows journal entry voucher no and related journal lines
- **Account Balance**: Current balance for associated account

---

## 5. Journals & Vouchers

### Add Journal Screen (Voucher Screen)
**File**: `lib/screens/journal/journal_voucher_screen.dart`

### Journal List Screen
**File**: `lib/screens/journal/journal_list_screen.dart`

#### Features
- Lists all journal entries for a business
- Shows voucher no, date, description
- Tap to view journal detail
- FAB to add new journal

### Journal Create Screen
**File**: `lib/screens/journal/journal_create_screen.dart`

#### Features
- **Date & Description**: Input fields with validators
- **Dynamic Journal Lines**: Add/remove rows for debit/credit entries
  - Account ID input
  - Debit amount
  - Credit amount
- **Add Line Button**: Creates new empty journal line row
- **Remove Button**: Deletes journal line row
- **Validation**: 
  - All fields required
  - Total debits must equal total credits
- **Save Flow**:
  1. Generate voucher number (JV-1, JV-2, etc.)
  2. Create journal_entry with voucher, date, description
  3. Create journal_line for each row
  4. Show success SnackBar and return to list

### Journal Detail Screen
**File**: `lib/screens/journal/journal_detail_screen.dart`

#### Display
- **Journal Header**: Voucher no, date, description
- **Line Items**: Account ID, debit, credit for each journal line

---

## 6. Reports

### Reports Menu Screen
**File**: `lib/screens/reports/reports_screen.dart`

Lists all available reports:
1. **Trial Balance**
2. **Profit & Loss**
3. **Balance Sheet**
4. **Cash Book**
5. **Expense Report**

### Trial Balance Report
**File**: `lib/screens/reports/trial_balance_screen.dart`

#### Data Query
```
SELECT accounts.account_id, accounts.name,
       SUM(journal_lines.debit) as total_debit,
       SUM(journal_lines.credit) as total_credit
FROM journal_lines
INNER JOIN accounts ON accounts.account_id = journal_lines.account_id
GROUP BY accounts.account_id
```

#### Display
- List of accounts with debit and credit totals
- Summary row showing total debits and total credits
- **Validation**: Total debits should equal total credits

### Profit & Loss Report
**File**: `lib/screens/reports/profit_loss_screen.dart`

#### Data Calculation
- **Income**: Sum of credits for Revenue/Income accounts
- **Expense**: Sum of debits for Expense accounts
- **Net Profit**: Income - Expense

#### Display
- Income total
- Expense total
- Net profit (with colored background)

### Ledger Report
**File**: `lib/screens/reports/ledger_report_screen.dart`

#### Features
- Shows journal entries for a specific account
- Running balance calculation (opening balance + cumulative debits - credits)
- Date, voucher no, description, debit, credit columns

### Balance Sheet Report
**File**: `lib/screens/reports/balance_sheet_screen.dart`
- Placeholder (not yet implemented)

### Cash Book Report
**File**: `lib/screens/reports/cash_book_screen.dart`
- Placeholder (not yet implemented)

### Expense Report Screen
**File**: `lib/screens/reports/expense_report_screen.dart`
- Placeholder (not yet implemented)

---

## 7. Key Service Methods

### AccountingService

```dart
// Generate journal voucher (JV-1, JV-2, etc.)
Future<String> generateJournalVoucher()

// Create complete journal with lines (double-entry)
Future createCompleteJournal({
  required JournalEntryModel journalEntry,
  required List<JournalLineModel> journalLines,
})

// Get account balance (debit - credit)
Future<double> getAccountBalance(int accountId)

// Get cash account ID for a business
Future<int?> getCashAccountId(int businessId)

// Get cash balance for business
Future<double> getCashBalanceForBusiness(int businessId)

// Dashboard summary
Future<Map<String, double>> getDashboardSummary(int businessId)

// Get ledger entries for account
Future<List<Map<String, dynamic>>> getLedgerForAccount(
  int businessId, int accountId
)

// Trial balance (all accounts with debits/credits)
Future<List<Map<String, dynamic>>> getTrialBalance()

// Profit & Loss
Future<Map<String, dynamic>> getProfitLoss(int businessId)
```

### JournalService

```dart
// Get all journal entries for business
Future<List<JournalEntryModel>> getJournalEntries(int businessId)

// Get journal lines for entry
Future<List<Map<String, dynamic>>> getJournalLines(int journalId)

// Create journal entry
Future<int> createJournalEntry(
  int businessId, String voucher, String date, String description
)

// Create journal line
Future<void> createJournalLine(
  int journalId, int accountId, double debit, double credit
)
```

### AccountService

```dart
// Create account
Future<int> createAccount(AccountModel account)

// Update account
Future<void> updateAccount(AccountModel account)

// Get account by ID
Future<AccountModel?> getAccountById(int accountId)

// Get all accounts for business
Future<List<AccountModel>> getAccountsByBusiness(int businessId)

// Create default accounts (Cash, Expense, Utilities)
Future<void> createDefaultAccounts(int businessId)
```

---

## 8. Database Schema

### Key Tables

**accounts**
```sql
CREATE TABLE accounts (
  account_id INTEGER PRIMARY KEY,
  business_id INTEGER,
  name TEXT,
  type TEXT,
  phone TEXT,
  address TEXT,
  opening_balance REAL,
  created_at TEXT
)
```

**journal_entry**
```sql
CREATE TABLE journal_entry (
  journal_id INTEGER PRIMARY KEY,
  business_id INTEGER,
  voucher_no TEXT UNIQUE,
  date TEXT,
  description TEXT,
  created_at TEXT
)
```

**journal_lines**
```sql
CREATE TABLE journal_lines (
  line_id INTEGER PRIMARY KEY,
  journal_id INTEGER,
  account_id INTEGER,
  debit REAL,
  credit REAL
)
```

**transactions**
```sql
CREATE TABLE transactions (
  transaction_id INTEGER PRIMARY KEY,
  business_id INTEGER,
  account_id INTEGER,
  amount REAL,
  date TEXT,
  payment_method TEXT,
  type TEXT,
  description TEXT,
  image_url TEXT,
  created_at TEXT
)
```

---

## 9. How to Use: End-to-End Workflow

### Creating an Expense Transaction
1. Go to Dashboard → "Add Transaction"
2. Select date/time, account (e.g., "Utilities"), side (Debit), amount (500)
3. Add description and optional image
4. Set payment method and type
5. Tap Save
6. System creates:
   - TransactionModel entry in DB
   - journal_entry with generated voucher
   - Two journal_lines: Cash (Credit 500) and Utilities (Debit 500)
7. Dashboard and Account Detail balance updates automatically

### Viewing Account Ledger
1. Go to Accounts tab
2. Tap an account
3. Tap "Ledger" button
4. See running ledger with all transactions for that account

### Generating Trial Balance
1. Go to Dashboard → Reports → "All Reports" → Trial Balance
2. See all accounts with debit/credit totals
3. Verify total debits = total credits

### Creating Manual Journal Entry
1. Go to Dashboard → "Add Journal"
2. Enter date, voucher description
3. Add lines: Account, Debit, Credit
4. Add Line button to create more rows
5. Ensure debits = credits
6. Save

---

## 10. Validation & Error Handling

### Double-Entry Validation
- All journal saves validate debit = credit
- Error shown if imbalanced

### Account Type Filters
- Transaction filters (Expense/Income) use account type lookup
- Displays only matching transactions

### Database Constraints
- Unique voucher numbers per business
- Foreign keys: accounts, journal_entry, journal_lines
- Opening balance as decimal

---

## 11. Theme & UI

### Colors (AppColors from theme.dart)
- **Primary**: Main app color (used for AppBar, buttons)
- **Cards**: Light backgrounds for summary cards
- **Status**: Green (success), Red (error), Orange (warning)

### Common Patterns
- **SnackBar**: Success/error feedback
- **FutureBuilder**: Loading data asynchronously
- **RefreshIndicator**: Pull-to-refresh dashboard
- **ChoiceChip**: Filter selection
- **DropdownButtonFormField**: Type selection

---

## 12. Next Steps (Not Yet Implemented)

- **Balance Sheet**: Compute assets, liabilities, equity by account type
- **Cash Book**: Filter journal entries for cash account only
- **Expense Report**: Monthly aggregation by expense category
- **File Export**: Export reports as PDF/Excel
- **Notifications**: Alert on low cash balance
- **Multi-currency**: Support for multiple currencies
- **Budget vs Actual**: Compare budget targets to actual spending

---

## 13. Quick Reference: File Locations

```
lib/
├── db/
│   └── database_helper.dart          # All DB operations
├── models/
│   ├── account_model.dart
│   ├── transaction_model.dart
│   ├── journal_entry_model.dart
│   └── journal_line_model.dart
├── services/
│   ├── accounting_service.dart       # Financial calculations
│   ├── account_service.dart
│   ├── transaction_service.dart
│   ├── journal_service.dart
│   └── business_service.dart
└── screens/
    ├── dashboard/
    │   └── dashboard_screen.dart
    ├── accounts/
    │   ├── account_screen.dart
    │   ├── add_account_screen.dart
    │   └── account_detail_screen.dart
    ├── transactions/
    │   ├── add_transaction_screen.dart
    │   ├── transaction_list_screen.dart
    │   └── transaction_detail_screen.dart
    ├── journal/
    │   ├── journal_list_screen.dart
    │   ├── journal_create_screen.dart
    │   ├── journal_detail_screen.dart
    │   └── journal_voucher_screen.dart
    └── reports/
        ├── reports_screen.dart
        ├── trial_balance_screen.dart
        ├── profit_loss_screen.dart
        ├── ledger_report_screen.dart
        ├── balance_sheet_screen.dart
        ├── cash_book_screen.dart
        └── expense_report_screen.dart
```

---

## 14. Support & Troubleshooting

### Common Issues

**Journal Save Fails**: Ensure debits equal credits in all lines

**Transactions Not Showing in Ledger**: Verify account ID is correct and journal lines were created

**Balance Shows 0**: Check if any transactions exist for the account; opening balance is used as fallback

**Report Shows No Data**: Verify journal entries exist in database; some reports may require specific account types

### Debug Tips
- Check DatabaseHelper logs for SQL errors
- Verify FutureBuilder futures are completing
- Use print() statements in service methods for debugging

---

## Document Version
- **Last Updated**: February 2025
- **Status**: Complete feature implementation with scaffolds for remaining reports
