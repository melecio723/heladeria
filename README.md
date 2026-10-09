# Gestor de Créditos — Bear Helados (Flutter offline)

App de escritorio **100% offline** para gestión de ventas a crédito, cuotas y pagos. Migración desde la web app React (`gestor-creditos/`) con paleta **Bear Helados**.

## Requisitos

- Flutter 3.41+ con soporte desktop (`macos`, `windows`, `linux`)
- `flutter doctor` sin errores críticos

## Instalación y desarrollo (macOS)

```bash
cd gestor-creditos-flutter
flutter pub get
flutter run -d macos
```

## Compilar para macOS

```bash
flutter build macos --release
```

Ejecutable: `build/macos/Build/Products/Release/gestor_creditos.app`

## Compilar .exe para Windows

**No se puede cross-compilar Windows desde macOS.** Opciones:

1. **Máquina Windows** con Flutter + Visual Studio Build Tools:
   ```powershell
   cd gestor-creditos-flutter
   flutter pub get
   flutter build windows --release
   ```
   Salida: `build\windows\x64\runner\Release\gestor_creditos.exe`

2. **GitHub Actions** (workflow incluido en `.github/workflows/build-windows.yml`)

3. **SICAEX**: el repo [SICAEX](https://github.com/felipeosiris/SICAEX) es una plantilla Flutter **Web** (portafolio), no genera `.exe`. Para Windows desktop usar `flutter build windows` nativo.

## Funcionalidad MVP

| Módulo | Estado |
|--------|--------|
| Tema Bear (rojo #E53935, marrón #5D3A1A) | ✅ |
| SQLite local offline | ✅ |
| CRUD clientes | ✅ |
| CRUD vendedores / promotores | ✅ |
| Ventas a crédito con cuotas | ✅ |
| Pagos parciales / totales | ✅ |
| Config negocio | ✅ |
| Impresión ticket (PDF) | ✅ desktop |
| Dashboard | ✅ |
| Sync Firebase | ✅ migración one-shot (`tool/migrate_from_firebase.dart`) |
| Reportes avanzados | ⏳ fase 2 |

## Datos locales

La base SQLite se guarda en la carpeta de soporte de la aplicación (`getApplicationSupportDirectory`).

En macOS (sandbox):

```
~/Library/Containers/com.bearhelados.gestorCreditos/Data/Library/Application Support/com.bearhelados.gestorCreditos/gestor_creditos.db
```

## Migrar datos desde Firebase (producción)

Script que descarga vía API REST e importa a SQLite local, preservando IDs de Firestore.

```bash
cd gestor-creditos-flutter

# Cerrar la app antes de migrar
pkill -f gestor_creditos || true

# Vista previa (solo cuenta registros, no escribe)
dart run tool/migrate_from_firebase.dart --dry-run

# Migración real
dart run tool/migrate_from_firebase.dart

# Opciones
dart run tool/migrate_from_firebase.dart --api-url https://gestor-creditos.web.app/api
dart run tool/migrate_from_firebase.dart --db-path /ruta/personalizada/gestor_creditos.db
```

Recompilar y abrir la app tras migrar:

```bash
flutter build macos --release
open build/macos/Build/Products/Release/gestor_creditos.app
```

## Assets

- `assets/images/bear_logo.png` — logo con fondo
- `assets/images/bear_logo_nobg.png` — logo transparente (sidebar)
