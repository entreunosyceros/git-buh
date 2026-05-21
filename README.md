# git-BUH

**Archivo del programa:** `git-BUH.sh`

Programa interactivo en bash para **aprender Git de cero**: instala y configura Git en Ubuntu, explica cómo preparar tu cuenta de GitHub, y guía diez ejercicios prácticos con verificación automática (del repositorio local al flujo profesional).

Todo el texto del menú y las guías está en **español**. Los ejercicios se ejecutan en el **directorio desde el que lanzas** `./git-BUH.sh` (tu sandbox de práctica).

## Requisitos

| Componente | Uso |
|------------|-----|
| **Bash** 4+ | Ejecutar el script |
| **Git** | Commits, ramas, merge, remoto (opción 0 puede instalarlo con `apt`) |
| **openssh-client** | `ssh`, `ssh-keygen` para `git@github.com:…` (opción 0 y ejercicios 6, 9) |
| **Cuenta GitHub** + red | Ejercicios 6, 7, 9 y 10 (push y prueba SSH) |
| **GitHub CLI** (`gh`) | Opcional, solo sugerido en el ejercicio 6 |

En Ubuntu/Debian la opción 0 puede instalar paquetes con `sudo` si lo confirmas (`git`, `openssh-client`).

## Inicio rápido

```bash
mkdir -p ~/practica-git
cd ~/practica-git
chmod +x /ruta/a/git-BUH.sh
/ruta/a/git-BUH.sh
```

Desde el directorio del repositorio del programa:

```bash
chmod +x git-BUH.sh
./git-BUH.sh
```

En el menú escribe `0` la primera vez, luego sigue del `1` al `10`. Pulsa **`r`** para ver este README dentro del programa. Para salir: `q` o `salir`.

El progreso se guarda en `.git-buh-progreso` en tu carpeta de práctica. Si tenías `.ejercicios-git-progreso` de una versión anterior, se migra al arrancar.

## Menú

| Opción | Contenido |
|--------|-----------|
| **0** | Instalar/configurar Git, SSH, identidad local y **guía para configurar GitHub** |
| 1 | Crear repositorio local (`git init`) |
| 2 | Cinco commits |
| 3 | Ramas `feature/login` y `feature/docs` |
| 4 | Fusionar ramas |
| 5 | Resolver conflictos de merge |
| 6 | Subir el proyecto a GitHub (`origin`, `push`) |
| 7 | Trabajo en pareja (bare + clones `dev-a` / `dev-b`) |
| 8 | `.gitignore` |
| 9 | SSH con GitHub (verificación `ssh -T`) |
| 10 | Flujo profesional (`--no-ff`, tag `v1.0.0`) |

- **README**: `r` o `readme` — muestra la ruta de `README.md` y opción de leerlo con `less`.
- **Salir**: `q` o `salir` (no hay número de salida).
- **Orden recomendado**: 0 → 10. Los ejercicios 1–10 piden Git instalado; la opción 0 puede hacerlo por ti.

Cada ejercicio muestra pasos en pantalla y **comprueba** que cumples los requisitos antes de marcar ✓. Puedes reintentar la verificación o volver al menú.

## Opción 0: Git local + GitHub

La opción 0 es el punto de partida. No sustituye a los ejercicios 6 y 9, pero deja el entorno listo y explica cómo encaja todo.

### En tu PC (automatizado con confirmación)

1. **Git** — Comprueba si está instalado; en Ubuntu/Debian ofrece `sudo apt-get install -y git`.
2. **Identidad Git** — Pide `user.name` y `user.email` (obligatorios para commits y para alinearlos con GitHub).
3. **Valores recomendados** (opcional) — `init.defaultBranch main`, `color.ui auto`, `pull.rebase false`.
4. **OpenSSH** — Comprueba o instala `openssh-client`.
5. **Claves SSH** — Lista las `*.pub` en `~/.ssh/` del usuario Linux actual; puedes elegir una, crear una con nombre personalizado o saltar.
6. **Preferencia git-BUH** — Guarda en `~/.config/git-buh/`:
   - `clave-ssh-preferida` — ruta de la clave privada
   - `host-github` — `github.com` o un alias de `~/.ssh/config`
7. **Prueba opcional** — `ssh -T git@HOST` con esa clave.

No guarda contraseñas, tokens ni el contenido de claves privadas.

### Guía: configurar la cuenta de GitHub

Tras lo anterior, el programa muestra una guía paso a paso (**pasos A–E**) para enlazar Git local con GitHub:

| Paso | En GitHub / en la web |
|------|------------------------|
| **A** | Crear cuenta o iniciar sesión, elegir usuario, verificar email |
| **B** | Perfil y email de commits (coincidir con `git config user.email` o usar noreply) |
| **C** | Settings → SSH and GPG keys → pegar tu `.pub` → probar `ssh -T git@github.com` |
| **D** | Crear repositorio vacío (sin README si ya tienes commits locales) |
| **E** | `git remote add origin …` y `git push -u origin main` (lo practicas en el ejercicio 6) |

También describe la alternativa **HTTPS** con Personal Access Token.

### Cómo se relacionan Git y GitHub

```
  Tu PC                          GitHub
  ┌──────────────────┐           ┌─────────────────────┐
  │ git config         │           │ Cuenta, email,      │
  │ user.name / email  │  ◄──────► │ perfil              │
  ├──────────────────┤           ├─────────────────────┤
  │ ~/.ssh/clave     │  clave    │ Settings → SSH keys │
  │ ssh -T git@…     │  .pub     │                     │
  ├──────────────────┤           ├─────────────────────┤
  │ .git/ commits    │  push     │ Repositorio remoto  │
  │ git remote origin│ ◄───────► │ (origin)            │
  └──────────────────┘           └─────────────────────┘
```

La opción 0 se marca completada (✓) cuando hay **Git en el PATH** y **user.name** + **user.email** globales. La autenticación SSH con GitHub se verifica en el **ejercicio 9**; el **push** al remoto, en el **6**.

## Varios usuarios o varias cuentas en el mismo equipo

| Situación | Qué hacer |
|-----------|-----------|
| **Varios usuarios Linux** (`juan`, `maria`, …) | Cada uno ejecuta `./git-BUH.sh` con su usuario. Cada uno tiene su `~/.ssh/` y su `~/.config/git-buh/`. |
| **Un usuario, varias cuentas GitHub** | Una clave por cuenta (p. ej. `~/.ssh/id_ed25519_trabajo`) y bloques `Host` en `~/.ssh/config`. Remoto: `git@github.com-trabajo:org/repo.git`. |
| **Preferencia guardada** | `~/.config/git-buh/clave-ssh-preferida` y `host-github` |

El ejercicio 9 reutiliza el flujo SSH y exige que `ssh -T` con GitHub funcione con la clave preferida (o la primera `.pub` encontrada).

## Ejercicios 1–10 (resumen)

- **1** — `git init`, existe `.git`.
- **2** — Al menos 5 commits, working tree limpio.
- **3** — Ramas `feature/login`, `feature/docs` y al menos 3 ramas locales.
- **4** — `feature/login` fusionada en la rama principal.
- **5** — Conflicto de merge resuelto (escenario asistido opcional).
- **6** — Remoto `origin` y upstream configurado (`git push -u`).
- **7** — Bare `../pareja-repo.git` y clones `../dev-a`, `../dev-b` sincronizados.
- **8** — `.gitignore` e ignorar `prueba.log`.
- **9** — Cliente SSH, clave en `~/.ssh/`, prueba exitosa con GitHub.
- **10** — Rama `feature/release-prep`, merge `--no-ff`, tag `v1.0.0`, ≥ 8 commits.

## Archivos y carpetas que puede crear git-BUH.sh

| Ruta | Cuándo |
|------|--------|
| `.git-buh-progreso` | Progreso en tu carpeta de práctica |
| `~/.config/git-buh/` | Preferencia de clave SSH (opción 0 / 9) |
| `../pareja-repo.git`, `../dev-a`, `../dev-b` | Ejercicio 7 (respecto al directorio de práctica) |
| `.git/` y archivos del sandbox | Ejercicios 1–10 |

## Advertencias

- Usa una **carpeta dedicada** a la práctica, no un proyecto importante sin copia de seguridad.
- La opción 0 puede usar **sudo** para `apt`.
- git-BUH **no** almacena tokens de GitHub ni contraseñas.
- El ejercicio 7 escribe fuera de tu carpeta actual (directorio padre).

## Estructura del proyecto

```
ejercicios_git_basicos/
├── git-BUH.sh   # Programa principal (menú, opción 0, ejercicios 1–10; código comentado en español)
└── README.md    # Este archivo
```

El código fuente de `git-BUH.sh` incluye comentarios en cada función y en las partes más delicadas (SSH multi-clave, verificadores, escenarios de conflicto y pareja).

## Licencia y contribuciones

Script de práctica educativa. Puedes copiar `git-BUH.sh` (y opcionalmente este `README.md`) donde quieras enseñar o practicar Git.

Tras terminar, puedes borrar la carpeta de práctica y empezar de nuevo en otra ruta vacía; el historial Git queda solo en ese sandbox.
