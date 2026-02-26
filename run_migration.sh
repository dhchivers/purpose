#!/bin/bash

# Migration Helper Script
# 
# This script helps you run the data migration safely with proper checks.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Firebase Multi-Strategy Migration Helper${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter not found. Please install Flutter first."
    exit 1
fi

print_success "Flutter found: $(flutter --version | head -n 1)"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    print_warning "Firebase CLI not found. Some features may not work."
    echo "  Install with: npm install -g firebase-tools"
else
    print_success "Firebase CLI found: $(firebase --version)"
fi

# Get Flutter dependencies
echo ""
print_info "Ensuring Flutter dependencies are up to date..."
flutter pub get > /dev/null 2>&1
print_success "Dependencies ready"

# Show menu
echo ""
echo -e "${BLUE}Select migration option:${NC}"
echo "  1) Dry run - Preview changes (safe, no modifications)"
echo "  2) Test migration - Single user (requires user ID)"
echo "  3) Full migration - All users (⚠️  MODIFIES DATABASE)"
echo "  4) Check Firebase connection"
echo "  5) View migration guide"
echo "  6) Exit"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo ""
        print_info "Running dry run migration..."
        echo ""
        dart migrate_to_strategies.dart --dry-run
        ;;
    2)
        echo ""
        read -p "Enter user ID to test: " user_id
        if [ -z "$user_id" ]; then
            print_error "User ID cannot be empty"
            exit 1
        fi
        echo ""
        print_warning "This will MODIFY data for user: $user_id"
        read -p "Continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            print_info "Migration cancelled"
            exit 0
        fi
        echo ""
        dart migrate_to_strategies.dart --user-id="$user_id"
        ;;
    3)
        echo ""
        print_error "⚠️  WARNING: This will modify ALL user data in your database!"
        echo ""
        print_info "Before proceeding, ensure you have:"
        echo "  1. Backed up your Firestore database"
        echo "  2. Run a dry run to preview changes"
        echo "  3. Tested on a single user successfully"
        echo ""
        read -p "Have you completed all the above steps? (yes/no): " prepared
        if [ "$prepared" != "yes" ]; then
            print_info "Please complete the preparation steps first."
            exit 0
        fi
        echo ""
        read -p "Type 'MIGRATE' to confirm full migration: " confirm
        if [ "$confirm" != "MIGRATE" ]; then
            print_info "Migration cancelled"
            exit 0
        fi
        echo ""
        print_warning "Starting full migration in 3 seconds... (Ctrl+C to cancel)"
        sleep 3
        dart migrate_to_strategies.dart
        ;;
    4)
        echo ""
        print_info "Testing Firebase connection..."
        dart -e "
        import 'package:firebase_core/firebase_core.dart';
        import 'package:cloud_firestore/cloud_firestore.dart';
        
        Future<void> main() async {
          try {
            await Firebase.initializeApp(
              options: FirebaseOptions(
                apiKey: 'AIzaSyD3dLLJuYznC0qzDiqp2t_KQ_dqyqKKYU4',
                authDomain: 'altruency-purpose.firebaseapp.com',
                projectId: 'altruency-purpose',
                storageBucket: 'altruency-purpose.firebasestorage.app',
                messagingSenderId: '519798970874',
                appId: '1:519798970874:web:5e15b35cb136868c5e6c43',
              ),
            );
            
            final db = FirebaseFirestore.instance;
            final count = await db.collection('users').count().get();
            
            print('✓ Connection successful!');
            print('✓ Found \${count.count} users in database');
          } catch (e) {
            print('✗ Connection failed: \$e');
          }
        }
        " 2>&1 | grep -E "✓|✗" || print_error "Connection test failed"
        ;;
    5)
        echo ""
        if [ -f "MIGRATION_GUIDE.md" ]; then
            less MIGRATION_GUIDE.md
        else
            print_error "MIGRATION_GUIDE.md not found"
        fi
        ;;
    6)
        print_info "Exiting"
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
print_success "Done!"
