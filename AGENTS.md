# AGENTS.md

## Project

Voxlab — gamified public-speaking trainer. Single Flutter package (no monorepo), light-theme Material 3 app backed by a REST API at `https://tvoxlab.tech/api/v1` (`lib/core/constants/app_constants.dart`). UI copy is Spanish.

## Commands

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # codegen
flutter analyze
flutter test            # single file: flutter test test/widget_test.dart
flutter run -t lib/main_demo.dart   # offline demo: signed-in user, fixture content
```

`lib/main_demo.dart` overrides the auth/content/storage providers with `lib/dev/demo_data.dart`, so every screen can be reviewed without a backend account. Never import `lib/dev/` from production code.

After touching `lib/domain/models/*` (freezed/json_serializable): codegen -> analyze -> test, in that order.

## Testing the tabs

- `test/tabs_smoke_test.dart` renders **every tab** (mapa, práctica, analizar, perfil) with fixture providers at 390x844 and 320x700, asserting no layout exception and checking real content/logic (filtering, empty states, no raw type strings). Run it after touching any screen: it is what catches responsive overflows.
- `test/golden/tab_screens_golden_test.dart` captures the full tab screens for design review; read the PNGs from `test/golden/goldens/` when changing shared styles.
- Tests call `useReducedMotion(tester)` (`test/golden/golden_fonts.dart`) before pumping. Decorative loops (`Bob`, `PulseHalo`) never settle, so without it `pumpAndSettle` times out; with it they render their static frame and goldens stay deterministic. Do the same in any new widget test that renders the mascot or the map.
- Provider overrides needed for those tests: `tracksProvider` (fixtures), `progressNotifierProvider` (fake notifier with `List<Progress> build()`), `authProvider` (a real `AuthNotifier` built with fake repo/storage/api — its constructor requires non-null dependencies).
- `test/fixtures/map_fixtures.dart` must build `ExerciseContent` matching the exercise `type`: screens derive filter chips and XP from the parsed content, not the raw string.

## Known state

- `flutter test` passes (smoke test + auth widget tests).
- `flutter analyze` reports ~70 info-level issues as baseline (strict lint set in `analysis_options.yaml`). Match the lints on new code; don't mass-reformat unrelated files.
- **Mapa unificado** (Fase 3): `/track`, `/module`, `/lesson` routes eliminados; `TrackDetail`/`ModuleDetail`/`LessonList` pantallas borradas; tap en un nodo abre un popover anclado con EMPEZAR/REPASAR; scroll automático al nodo actual al cargar.
- **Errores user-friendly** (Fase 1): ErrorView con mensajes totales en español, `main.dart` con fallback styled en release, `friendlyErrorMessage()` centralizado.
- **Registro defensivo** (Fase 2): `_parseAuthResponse` tolerante + error amigable, catch visible en banner, validador de email estricto, tests de registro con fake repo (4 casos).
- **iOS**: needs Xcode + CocoaPods (`brew install cocoapods`; `flutter_secure_storage` 9.x has no Swift Package Manager support). `ios/Podfile` and `Podfile.lock` are committed; run CocoaPods with `LANG=en_US.UTF-8`. Info.plist allows `NSAllowsLocalNetworking` so a local http backend works in the simulator; the launch screen is brand orange and the app icon is generated from `assets/images/voxi_logo.png`.
- Para desarrollo local con Docker: `cd backend && docker compose up -d backend`, luego `flutter run --dart-define=API_BASE_URL=http://<ip-pc>:3000/api/v1` (o `adb reverse tcp:3000 tcp:3000` + `127.0.0.1`). `usesCleartextTraffic="true"` habilitado en AndroidManifest para http://.

## Codegen facts

- `*.freezed.dart` / `*.g.dart` are committed. Never hand-edit; never delete.
- Only freezed/json_serializable codegen exists (`build_runner`). Riverpod codegen deps were removed — providers are always written manually (`Provider`, `Notifier` style in `presentation/shared/providers/`).

## Architecture

Layers, dependencies point inward:

- `lib/core/` — theme, go_router setup, dio network client (+ auth interceptor), secure storage
- `lib/domain/` — freezed models, repository interfaces (`i_*`); no Riverpod here
- `lib/data/` — dio services per endpoint + repository impls
- `lib/presentation/features/<feature>/` — screens/widgets per feature; cross-feature Riverpod state lives in `presentation/shared/providers/`

Non-obvious wiring:

- All route paths in one place: `core/router/routes.dart`. Tabs: `/map` (Aprender), `/practice`, `/analyze`, `/profile` — all inside the `ShellRoute` with `app_shell.dart` bottom `NavigationBar`. There is no `/home` route anymore.
- **Authentication is mandatory**: `AuthGuard.check` redirects every unauthenticated navigation to `/auth-wall` (no guest mode). Splash sends unauthenticated users to the wall; logout lands there too.
- Progression is **local-first**: points/completed exercises persist through `data/local/local_progress_store.dart` (JSON blob in secure storage) and the app works offline. `ProgressNotifier` backs them up on the server (`data/remote/services/progress_sync_service.dart`, `GET/POST /progress`): each completion is uploaded, and on load local and server ids are merged so progress follows the account to another device (the server also computes the streak). Sync failures never touch local data. `ProgressNotifier` watches the signed-in user id from `authProvider` and reloads that user's entries; auth code never touches progress directly.
- Exercise types (reading/quiz/writing/oratory) are dispatched by `presentation/shared/widgets/exercise_widget_factory.dart` — add new exercise types there. Type labels/icons helpers live in `utils/exercise_name_utils.dart`. Exercises complete with an `ExerciseOutcome` (score + optional `SessionResult`).
- Writing exercises call the backend AI (`POST /exercises/analyze-text`, see `data/remote/services/analyzer_service.dart`) and complete with the real AI score; on analyzer failure they degrade to the heuristic points. Quiz/reading/oratory have no AI endpoint yet (heuristic `SessionResultBuilder.fromScore`) — backend gaps are marked with `TODO(backend)` comments.
- Session results screen consumes `domain/models/session_result.dart`. `SessionResult.fromJson` maps the analyzer envelope (`{success, data: {score, score_breakdown, feedback,...}}`); `SessionResultBuilder.fromScore` is the offline fallback — do not scatter fallback logic across UI.
- Reusable design components live in `presentation/shared/widgets/` — see "Design system" below. Prefer them over hand-rolling cards, buttons, tags or bars.

## Theme / design system

Single source: `core/constants/app_theme.dart` (`AppTheme.light`, `useMaterial3: true`) + `core/constants/app_colors.dart`. VoxLab warm palette: orange background `#F4A221`, intense red accent `#D93B27`, dark brown text `#5C3A21`, success green `#3ECF6E`, white surfaces. Each brand color has a darker "lip" shade (`primaryDark`, `accentRedDark`, `successDark`, `darkBrownDeep`); white cards use `cardBorder` + `cardLip`; idle map nodes `idleFace`/`idleLip`; rewards `gold`/`goldDark`. Fonts: DM Sans via google_fonts, **bundled in `assets/fonts/`** (see Fonts below). Always consume theme colors/components — no hardcoded hexes (the only sanctioned exceptions live inside map widgets, e.g. the white road).

### Design system (Duolingo-style)

- `chunky.dart`: `ChunkyButton` (3D push button, labels in UPPERCASE), `ChunkyCard` (white or colored face over a darker lip; pass `onTap` to make it sink on press), `ChunkyTag` (type/XP/status pill), `ChunkyColors` presets (`red`, `green`, `brown`, `orange`, `gold`, `white`, `idle`), `Pressable` for custom 3D surfaces.
- `exercise_type_style.dart`: one color + filled icon per exercise type (reading orange, quiz red, writing green, oratory brown) and `ink` for text on a light tint. Use it everywhere a type is shown.
- `motion.dart`: `EntranceAnimation` (+ `stagger(i)`), `Bob`, `PulseHalo`, `ConfettiBurst`. All honor `MediaQuery.disableAnimations` and use no timers.
- `lesson_widgets.dart`: lesson background (cream), `VoxiSays` (mascot + speech bubble prompt), `LessonProgressBar`, `AnswerFeedbackPanel`.
- `tab_header.dart`, `stat_tile.dart`, `top_stats_bar.dart` (streak/XP/completed bar on the map), `xp_bar.dart`, `skill_bar.dart`.
- Tabs use the orange background with a `TabHeader`; exercise screens use the cream lesson background with their own top bar (close, type badge, name, XP). The bottom bar is the custom `_NavItem` row in `core/router/app_shell.dart`.

## Map path

- `features/map/widgets/map_path_model.dart` derives the path from tracks + completed ids (`MapPathModel.build`): one `PathUnit` per module, one global current node (the first incomplete exercise across all tracks), unit colors rotating red/green/brown. Keep logic there, not in widgets.
- `features/map/widgets/map_geometry.dart` is the **single source of layout math** (`nodeDiameter`, `nodeDepth`, `nodeSpacing`, `topInset`, `bottomInset`, `amplitude`, `centers()`, `height()`). Layout (`Positioned` nodes) and painting (`PathConnectorPainter`) both consume it — never position nodes with `Transform`/`Column` stacking or hand-rolled math.
- `track_path.dart::buildMapSlivers` returns per unit a `SliverMainAxisGroup` with a pinned `UnitHeader` (stays on top while its unit scrolls) and a `UnitPathSection` (`Stack` sized by `MapGeometry.height(unit.slotCount)`; every unit ends with a trophy node, so `slotCount = exercises + 1`).
- Node styling: completed = unit color + check, current = unit color + type icon + unit-progress ring + pulse + floating EMPEZAR bubble, pending = cream idle node. Trophy turns gold when the unit is done. **No lock icons** (MVP: no gating).
- Tapping a node opens `showLessonPopover` (anchored card with EMPEZAR +XP / REPASAR); the header's book icon opens `showUnitGuide`. Voxi sits beside the widest swing of each unit (asleep on units ahead).

## Fonts and golden tests

- DM Sans variants are **bundled** (`assets/fonts/DMSans-*.ttf`, declared under family `DMSans` in `pubspec.yaml`) so `google_fonts` resolves them from the asset manifest — the app works offline and no runtime fetch happens.
- Golden tests live in `test/golden/` and use `golden_fonts.dart::loadGoldenFonts()` from `setUpAll`. `flutter test` runs the tester with `--disable-asset-fonts`/`--use-test-fonts`, so:
  - `MaterialIcons` must be registered with `FontLoader` or every `Icon` renders as a missing-glyph box;
  - `google_fonts` runtime fetching must stay disabled;
  - the first testWidgets run that uses a heavy weight lays text out before the font resolves and renders blocky fallback glyphs — keep the `warm up text pipeline` first test.
- Capture goldens on `find.byType(MaterialApp)` (full screen): capturing the widget alone composites its transparent background onto white and hides white-on-orange details.
- Call `settleImages(tester)` before every `expectLater`: `pumpAndSettle` drains frames but not the real async asset decode, so the first test of a run captures blank images. The Voxi mascot PNGs are also cropped to a tight 512x512 square, otherwise they render as an invisible smudge at 24-48px.
- Regenerate with `flutter test test/golden --update-goldens`. Map states covered: fresh / mid / all completed / narrow (320px). Goldens are rendered on macOS; small pixel differences on other machines are expected, so regenerate locally before comparing.

## Direction (decided by product owner)

MVP: users pick and run exercises freely — map path is informative only (no locks, no gating). **Authentication is mandatory** (guest mode removed by product decision; the backend `tvoxlab.tech` is unreachable from the current institutional network, so auth flows can't be live-tested here). **All progression data (XP, completed exercises, weekly chart) is computed and persisted locally** via `data/local/local_progress_store.dart`. Content, exercise scores and the AI session analysis (writing only, via `POST /exercises/analyze-text`) come from the backend; results map through `SessionResult` (see above). Backend gaps carry `TODO(backend)` comments for whoever picks them up.

## Conventions

- Conventional commits (`feat(ui):`, `fix(progress):`).
- Project skills for Flutter/Dart/testing live in `.agents/skills/` (indexed in `.atl/skill-registry.md`).
