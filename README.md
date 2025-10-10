# 🩸 Blockchain-Based Blood Bank Matching

A Clarity smart contract for tracking blood availability and matching donors with recipients using tokenized urgency flags on the Stacks blockchain.

## 🎯 Overview

This smart contract enables:
- 📊 Blood inventory management across all blood types
- 🩸 Donor and recipient registration
- ⚡ Urgency token system for critical cases
- 🤝 Automated compatibility matching
- 📈 Transparent tracking of all transactions

## 🩸 Blood Type Compatibility

The contract supports all major blood types and automatically validates compatibility:
- **Universal Donor**: O- can donate to anyone
- **Universal Recipient**: AB+ can receive from anyone
- **Type-specific**: A+/A- ↔ A+/AB+, B+/B- ↔ B+/AB+, etc.

## 🚀 Usage

### 📋 Register as a Donor
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching register-donor "O-")
```

### 🆘 Register as a Recipient
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching register-recipient "A+" u3)
```
*Urgency levels: 1-5 (5 = most critical)*

### 💉 Add Blood Inventory (Owner Only)
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching add-blood-inventory "O-" u10)
```

### ⚡ Issue Urgency Token (Owner Only)
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching issue-urgency-token u1 u5)
```

### 🤝 Match Donor with Recipient
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching match-donor-recipient u1 u1)
```

## 📖 Read Functions

### Check Blood Inventory
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching get-blood-inventory "O-")
```

### Get Donor Information
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching get-donor u1)
```

### Get Recipient Information
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching get-recipient u1)
```

### Check Urgency Token
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching get-urgency-token u1)
```

### View Match Details
```clarity
(contract-call? .Blockchain-Based-Blood-Bank-Matching get-match u1)
```

## 🔧 Setup & Deployment

1. **Install Clarinet**
   ```bash
   npm install -g @hirosystems/clarinet
   ```

2. **Deploy Contract**
   ```bash
   clarinet deploy
   ```

3. **Run Tests**
   ```bash
   clarinet test
   ```

## 📊 Contract Features

- ✅ **Blood Type Validation**: Ensures only valid blood types (A+, A-, B+, B-, AB+, AB-, O+, O-)
- ✅ **Compatibility Checking**: Automatic donor-recipient compatibility validation
- ✅ **Urgency System**: 5-level urgency rating with tokenized tracking
- ✅ **Inventory Management**: Real-time blood supply tracking
- ✅ **Match History**: Complete audit trail of all matches
- ✅ **Access Control**: Owner-only functions for critical operations

## 🔐 Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Invalid blood type |
| u102 | Insufficient inventory |
| u103 | Already registered |
| u104 | Record not found |
| u105 | Already matched |
| u106 | Invalid urgency level |
| u107 | Donor not available |
| u108 | Blood type incompatible |

## 🏗️ Architecture

The contract uses efficient data maps to store:
- **Blood Inventory**: Units available per blood type
- **Donors**: Registration and availability status
- **Recipients**: Requirements and urgency levels
- **Urgency Tokens**: Tokenized priority system
- **Matches**: Complete matching history

## 🌟 Benefits

- 🔒 **Immutable Records**: All transactions permanently recorded
- 🌐 **Decentralized**: No single point of failure
- ⚡ **Efficient Matching**: Automated compatibility checking
- 📊 **Transparent**: Public visibility of blood availability
- 🚨 **Priority System**: Urgency tokens for critical cases
