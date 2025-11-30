# Flutter Project Structure: General Perspective for Any App

This hybrid structure is designed for **any Flutter app**—from productivity tools and social apps to games or utilities. It's feature-first for modularity (organize around user journeys like "user onboarding" or "content feed"), with MVVM layers for separation of concerns. Start lean: Use the optional `domain/` only for features with intricate business logic (e.g., a game scoring system that combines player stats and rules). This scales from prototypes (skip deep layers) to enterprise apps (enforce via tools like very_good_cli).

## Key Adaptations for Generality

- Feature examples are neutral placeholders (e.g., `feature1/` for user management).
- Assumes Riverpod for state, but swap for Bloc/Provider by adjusting `view_models/`.
- Focus on reusability: Shared code only if truly cross-feature.

## Project Structure

```
lib/
├── app/                          # App-wide setup: Use for global config that ties the app together (e.g., themes, routing). Keeps main.dart clean. Ideal for any app's foundational styling/navigation.
│   ├── constants/                # Colors, strings, API keys: Use for immutable, app-wide values. Avoid feature-specific ones—put those in feature/model/. Great for consistent branding.
│   ├── themes/                   # Light/dark themes, text styles: Use ThemeData here; wrap in app.dart for easy switching. Essential for accessibility-focused apps.
│   ├── routes/                   # GoRouter config, route guards: Use for declarative navigation. Define paths like '/feature1/profile' here. Handles deep linking in any app.
│   └── app.dart                  # Root widget: MaterialApp.router + ProviderScope + theme/routing init. Use as the single app entry from main.dart. Add global error handlers here.
│
├── core/                         # Infrastructure: Use for cross-cutting concerns like networking or storage. Ideal for services shared across *all* features in any app type.
│   ├── network/                  # Dio client, interceptors, base URLs: Use for HTTP setup. Add auth tokens via interceptors. Key for API-heavy apps (e.g., social or data-driven).
│   ├── exceptions/               # Custom errors (e.g., NetworkException, ValidationError): Use to standardize error handling in repos. Improves debugging in any complex app.
│   ├── services/                 # External integrations (e.g., Firebase, Analytics, SecureStorage): Use for non-HTTP stuff. Mock for tests. Versatile for offline/online hybrids.
│   └── utils/                    # Global helpers (date formatters, loggers, validators): Use sparingly—only if reused in 3+ features. Otherwise, feature-specific. Handy for utility apps.
│
├── features/                     # Core modularity: Use feature folders for business capabilities (e.g., user management, content display). Add one per user journey; delete entire folder to remove a feature. Scales to any app size.
│   ├── feature1/                 # Example: User profile/onboarding flow (e.g., for auth or settings). (Simple feature—no domain/ needed unless advanced personalization.)
│   │   ├── data/                 # Data access: Use to abstract sources. Rename from 'repo/' for clarity if adding domain/.
│   │   │   └── repositories/     # Impl classes (e.g., Feature1RepositoryImpl): Use to fetch/transform data via core/services. Return Streams/Futures of models.
│   │   ├── presentation/         # UI + State: Use to group view/view_model—keeps features flat but layered.
│   │   │   ├── views/            # Stateless/Stateful widgets (e.g., Feature1View): Use "dumb" UI only—pass data via view_model. Test with flutter_test.
│   │   │   └── view_models/      # Riverpod providers (e.g., Feature1Notifier extends StateNotifier): Use for UI state/events. Consume repos/usecases; expose to views.
│   │   └── models/               # Fallback data if no domain/: Use here for simple features (e.g., Feature1 DTOs). Use freezed for immutability.
│   │
│   ├── feature2/                 # Example: Content listing/search (e.g., for feeds or galleries). (Simple—no domain/ needed.)
│   │   ├── data/                 # Repos only (e.g., Feature2Repository).
│   │   ├── presentation/
│   │   │   ├── views/            # Feature2View, ItemCard.
│   │   │   └── view_models/      # Feature2ViewModel.
│   │   └── models/               # Feature2Item, Comment models.
│   │
│   ├── feature3/                 # Example: Complex feature (e.g., scoring/levels in a game or analytics dashboard)—*use domain/* here for rules like "calculate score with multipliers."
│   │   ├── domain/               # Optional: Business rules. Use *only* if feature has complex logic (e.g., validate moves in a puzzle app). Skip for simple CRUD.
│   │   │   ├── models/           # Immutable data classes (e.g., Feature3Item.freezed): Use freezed/json_serializable for serialization. Keep pure—no API ties.
│   │   │   └── usecases/         # Orchestrators (e.g., CalculateFeature3UseCase): Use to compose repos (e.g., player + level data). Call from view_model.
│   │   ├── data/
│   │   │   └── repositories/     # Feature3Repository.
│   │   ├── presentation/
│   │   │   ├── views/            # Feature3BoardView.
│   │   │   └── view_models/      # Feature3ViewModel.
│   │   └── ...                   # (No fallback models if using domain/)
│   │
│   └── [more features]/          # e.g., feature4/ (notifications), feature5/ (payments): Scale by adding folders. If a feature spans others (e.g., search), extract to its own or use core/utils. Adapt to your app (e.g., chat/ for messaging apps).
│
├── global/                       # Reusables: Use for *truly* shared items across features. Audit yearly—move to features if underused. Crucial for UI consistency in any app.
│   ├── widgets/                  # Custom components (e.g., AppButton, LoadingDialog): Use for UI primitives. Subfolder by type (e.g., forms/) if >20 files. Saves time in design-heavy apps.
│   ├── providers.dart            # Global Riverpod setup (e.g., themeProvider): Use for app-level state (e.g., user session). Avoid feature state here.
│   └── bindings.dart             # Init hooks (e.g., Firebase.initializeApp()): Use for DI/lifecycle. Call in main.dart before runApp. Essential for plugin-heavy apps.
│
├── generated/                    # Auto-gen: Use for build_runner outputs (e.g., freezed models). .gitignore if not needed in repo. Common in data-serializing apps.
│   └── ...                       # e.g., feature1/models.g.dart
│
└── main.dart                     # Bootstrap: Use minimally—import app.dart, wrap in runApp, add env checks (e.g., dotenv). Keep it under 50 lines for any app.
```

## Directory Descriptions

### `app/`
App-wide setup: Use for global config that ties the app together (e.g., themes, routing). Keeps main.dart clean. Ideal for any app's foundational styling/navigation.

- **`constants/`**: Colors, strings, API keys. Use for immutable, app-wide values. Avoid feature-specific ones—put those in `feature/model/`. Great for consistent branding.
- **`themes/`**: Light/dark themes, text styles. Use ThemeData here; wrap in app.dart for easy switching. Essential for accessibility-focused apps.
- **`routes/`**: GoRouter config, route guards. Use for declarative navigation. Define paths like '/feature1/profile' here. Handles deep linking in any app.
- **`app.dart`**: Root widget: MaterialApp.router + ProviderScope + theme/routing init. Use as the single app entry from main.dart. Add global error handlers here.

### `core/`
Infrastructure: Use for cross-cutting concerns like networking or storage. Ideal for services shared across *all* features in any app type.

- **`network/`**: Dio client, interceptors, base URLs. Use for HTTP setup. Add auth tokens via interceptors. Key for API-heavy apps (e.g., social or data-driven).
- **`exceptions/`**: Custom errors (e.g., NetworkException, ValidationError). Use to standardize error handling in repos. Improves debugging in any complex app.
- **`services/`**: External integrations (e.g., Firebase, Analytics, SecureStorage). Use for non-HTTP stuff. Mock for tests. Versatile for offline/online hybrids.
- **`utils/`**: Global helpers (date formatters, loggers, validators). Use sparingly—only if reused in 3+ features. Otherwise, feature-specific. Handy for utility apps.

### `features/`
Core modularity: Use feature folders for business capabilities (e.g., user management, content display). Add one per user journey; delete entire folder to remove a feature. Scales to any app size.

#### Simple Feature Structure (feature1, feature2)
- **`data/repositories/`**: Implementation classes (e.g., Feature1RepositoryImpl). Use to fetch/transform data via core/services. Return Streams/Futures of models.
- **`presentation/views/`**: Stateless/Stateful widgets (e.g., Feature1View). Use "dumb" UI only—pass data via view_model. Test with flutter_test.
- **`presentation/view_models/`**: Riverpod providers (e.g., Feature1Notifier extends StateNotifier). Use for UI state/events. Consume repos/usecases; expose to views.
- **`models/`**: Fallback data if no domain/. Use here for simple features (e.g., Feature1 DTOs). Use freezed for immutability.

#### Complex Feature Structure (feature3)
- **`domain/models/`**: Immutable data classes (e.g., Feature3Item.freezed). Use freezed/json_serializable for serialization. Keep pure—no API ties.
- **`domain/usecases/`**: Orchestrators (e.g., CalculateFeature3UseCase). Use to compose repos (e.g., player + level data). Call from view_model.
- **`data/repositories/`**: Feature3Repository.
- **`presentation/views/`**: Feature3BoardView.
- **`presentation/view_models/`**: Feature3ViewModel.

### `global/`
Reusables: Use for *truly* shared items across features. Audit yearly—move to features if underused. Crucial for UI consistency in any app.

- **`widgets/`**: Custom components (e.g., AppButton, LoadingDialog). Use for UI primitives. Subfolder by type (e.g., forms/) if >20 files. Saves time in design-heavy apps.
- **`providers.dart`**: Global Riverpod setup (e.g., themeProvider). Use for app-level state (e.g., user session). Avoid feature state here.
- **`bindings.dart`**: Init hooks (e.g., Firebase.initializeApp()). Use for DI/lifecycle. Call in main.dart before runApp. Essential for plugin-heavy apps.

### `generated/`
Auto-gen: Use for build_runner outputs (e.g., freezed models). .gitignore if not needed in repo. Common in data-serializing apps.

### `main.dart`
Bootstrap: Use minimally—import app.dart, wrap in runApp, add env checks (e.g., dotenv). Keep it under 50 lines for any app.

## When to Use What: Quick Decision Guide (App-Agnostic)

### Start Simple (No Domain/)
For prototypes or small apps (<5 features, e.g., a todo list). Flatten to `view/`, `view_model/`, `repo/`—focus on shipping.

### Add Domain/ Per Feature
When logic gets tangled (e.g., in a fitness app, "compute workout score" from multiple data sources). Keeps `view_model/` UI-focused; use usecases for composability.

### Feature vs. Core/Global Placement
- **1 feature** → `features/X/`
- **2-3 features** → `global/`
- **all features/infra** → `core/`

Heuristic: "Does deleting this break the app holistically?"

### Scaling by App Type

#### Small/Prototype (<10k LOC)
Drop `presentation/` grouping; use raw `view/` and `view_model/`.

#### Medium (e.g., Social/Utility)
Full structure—leverages Riverpod for reactive UIs.

#### Large/Enterprise (e.g., Enterprise Tool)
Add `domain/` everywhere; integrate CI/CD with structure checks.

#### Game/Media App
Emphasize `global/widgets/` for animations; add `core/audio/` if needed.

### Testing/Maintainability
- Unit test repos/usecases (mock core/)
- Widget test views
- Use `integration_test/` for end-to-end in any app

### State/Arch Swaps
Riverpod assumed—for Bloc, rename `view_model/` to `bloc/`; for no-framework, merge into views. Always unidirectional flow.

## Summary

This setup is flexible for *any* app, promoting clean code without rigidity. For a specific app type (e.g., IoT dashboard), share details for tweaks!

