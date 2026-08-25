cd ~/Desktop/apartment_app

cat > README.md <<'EOF'
# 🏠 JUMAA

## Find Your Next Home 🇰🇪

JUMAA is a Kenyan apartment discovery and property management mobile application built with Flutter and Supabase.

JUMAA helps people discover apartments using **county, subcounty, and area**, view property details, and connect directly with property owners.

## ✨ Features

### 🏡 Apartment Seekers

- Search apartments
- Filter by county
- Filter by subcounty
- Filter by area
- View apartment details
- View property photos
- View available units
- Contact property owners

### 🏢 Property Owners

- Create an owner account
- Email verification
- Register apartments
- Add property information
- Add photos
- Add location
- Manage apartment units
- Manage property information
- Connect with potential tenants

### 🔐 Authentication

JUMAA uses Supabase Authentication for:

- Registration
- Login
- Email verification
- Password recovery
- Owner profiles
- Role-based access

### 📧 Email

Transactional emails are handled through a Supabase Edge Function and Brevo.

## 🗺️ How JUMAA Works

```text
User
 │
 ├── Find Apartment
 │      │
 │      ├── County
 │      ├── Subcounty
 │      └── Area
 │
 │      ↓
 │
 └── Browse Apartments
        │
        ├── Photos
        ├── Property Details
        ├── Available Units
        └── Contact Owner


Property Owner
 │
 ├── Register
 ├── Verify Email
 ├── Register Apartment
 ├── Add Property Details
 ├── Add Photos
 └── Manage Units