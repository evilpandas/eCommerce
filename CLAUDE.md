# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Technology Stack

- **Rails**: 8.1.2 (Ruby 4.0.2)
- **Database**: SQLite3 (development/test), with separate production databases for primary, cache, queue, and cable
- **Frontend**: Hotwire (Turbo + Stimulus), TailwindCSS via cssbundling-rails, Flowbite components
- **JavaScript**: ESBuild via jsbundling-rails
- **Authentication**: Devise
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable
- **Deployment**: Kamal with Docker

## Development Commands

### Initial Setup
```bash
bin/setup               # Install dependencies, prepare database, start dev server
bin/setup --skip-server # Setup without starting server
bin/setup --reset       # Reset database during setup
```

### Running the Application
```bash
bin/dev                 # Start development server (Foreman runs Rails server, JS watcher, CSS watcher)
bin/rails server        # Start Rails server only
```

### Testing
```bash
bin/rails test                  # Run all tests
bin/rails test TEST=path/to/test.rb       # Run single test file
bin/rails test:system           # Run system tests only
bin/rails db:test:prepare       # Prepare test database
```

### Code Quality & Security
```bash
bin/rubocop             # Lint Ruby code (Omakase rules)
bin/brakeman            # Security vulnerability scan
bin/bundler-audit       # Check gems for known vulnerabilities
yarn audit              # Check JavaScript dependencies
bin/ci                  # Run full CI suite locally
```

### Database
```bash
bin/rails db:prepare    # Create/migrate database
bin/rails db:migrate    # Run pending migrations
bin/rails db:rollback   # Rollback last migration
bin/rails db:seed       # Seed database
```

### Asset Compilation
```bash
yarn build              # Build JavaScript with ESBuild
yarn build:css          # Build CSS with TailwindCSS
bin/rails assets:precompile  # Precompile assets for production
```

## Project Architecture

### Application Module
The Rails application module is `ECommerce` (config/application.rb).

### Current Domain Models
- **User**: Devise authentication with email/password, includes address field
- **Product**: Basic eCommerce product with name, description, price

### Database Strategy
- Development/test use single SQLite database
- Production uses multiple SQLite databases:
  - `production.sqlite3` - Primary application data
  - `production_cache.sqlite3` - Solid Cache
  - `production_queue.sqlite3` - Solid Queue
  - `production_cable.sqlite3` - Solid Cable

### Frontend Architecture
- **Asset Pipeline**: Propshaft for serving, ESBuild for JS bundling, TailwindCSS for CSS
- **JavaScript**: Source in `app/javascript/`, builds to `app/assets/builds/`
- **CSS**: Source in `app/assets/stylesheets/application.tailwind.css`, builds to `app/assets/builds/application.css`
- **UI Framework**: Flowbite (Tailwind-based components)
- **Dev Workflow**: Foreman runs three processes concurrently (web server, JS watcher, CSS watcher)

### Testing Strategy
- **Framework**: Minitest (Rails default)
- **Parallel Execution**: Enabled with number_of_processors
- **Fixtures**: Located in `test/fixtures/`, automatically loaded
- **System Tests**: Capybara + Selenium WebDriver
- **Test Helper**: `test/test_helper.rb` configures parallel execution and fixtures

## Code Style

This project follows the **Rails Omakase** Ruby style guide via rubocop-rails-omakase. Run `bin/rubocop` to check compliance and `bin/rubocop -a` to auto-correct issues where possible.

## CI/CD

GitHub Actions runs four parallel jobs:
1. **scan_ruby**: Brakeman security scan + bundler-audit gem audit
2. **lint**: RuboCop style checking
3. **test**: Unit and integration tests
4. **system-test**: System tests with screenshot capture on failure

All CI jobs must pass before merging to main.

## Deployment

- **Method**: Kamal (containerized deployment)
- **Docker**: Multi-stage build with Ruby 4.0.2, Node 25.8.1
- **Server**: Thruster (HTTP acceleration for Puma)
- **Port**: 80 in production
- **Entry Point**: `bin/docker-entrypoint` prepares database before starting

## Authentication

User authentication is handled by Devise with the following modules enabled:
- `:database_authenticatable`
- `:registerable`
- `:recoverable`
- `:rememberable`
- `:validatable`

Routes are mounted at `/users` (devise_for :users).
