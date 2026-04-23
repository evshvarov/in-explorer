---
name: iris-cpf-passwordhash
description: >-
  Generates InterSystems IRIS PasswordHash values for configuration merge (merge.cpf)
  using the official passwordhash nanocontainer—not the IRIS image. Use when adding or
  changing [Startup] PasswordHash in a CPF merge file, Docker/IRIS deployment passwords,
  or when the user asks how to hash IRIS predefined-account passwords for containers.
---

# IRIS CPF PasswordHash (passwordhash nanocontainer)

## What this is

- **`PasswordHash`** is a `[Startup]` parameter in a CPF **merge** file. It sets the password for **predefined IRIS user accounts** that have at least one role (not CSPSystem) during **initial** deployment on UNIX/Linux—replacing the default `SYS` with the password corresponding to the hash.
- The value is **not** a plain password. It is: **hashed password**, **salt**, and optionally **work factor** and **algorithm**.

## Use the dedicated image (not IRIS)

Do **not** generate this hash by hand or by guessing ObjectScript APIs for merge files.

InterSystems publishes a **small Docker image** (nanocontainer) **`passwordhash`** that outputs a ready-to-paste `PasswordHash=...` line.

- **Image (example tag):** `containers.intersystems.com/intersystems/passwordhash:1.1`
- **Registry / docs:** see *Running InterSystems Products in Containers* → **Authentication and Passwords** → **The PasswordHash CPF setting**  
  https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=ADOCK#ADOCK_iris_images_password_auth  
- **Parameter reference:** `PasswordHash` in CPF reference  
  https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RACS_PasswordHash

## CPF syntax

```ini
[Startup]
PasswordHash=<hashed>,<salt>[,<workfactor>,<algorithm>]
```

Defaults in tooling are often **SHA512** and work factor **10000** (match these when generating unless you have a reason not to).

## Commands

**Interactive** (prompts twice):

```bash
docker run --rm -it containers.intersystems.com/intersystems/passwordhash:1.1 \
  -algorithm SHA512 -workfactor 10000
```

**Non-interactive** (pipe password on stdin; prefer for passwords containing `*`, `$`, or spaces):

```bash
printf '%s' 'YOUR_PLAINTEXT_PASSWORD' | docker run --rm -i \
  containers.intersystems.com/intersystems/passwordhash:1.1 \
  -algorithm SHA512 -workfactor 10000
```

Copy the full output line starting with `PasswordHash=` into the merge file’s `[Startup]` section.

**Help:**

```bash
docker run --rm containers.intersystems.com/intersystems/passwordhash:1.1 --help
```

## After changing PasswordHash

1. Put the **generated line** into **`merge.cpf`** (or equivalent merge file referenced by `ISC_CPF_MERGE_FILE`).
2. Align **any plaintext password** used by clients (e.g. `IRISPASSWORD` in Docker, ObjectScript extension settings) with the **same** password you hashed—merge files store only the hash, not the cleartext.
3. **`PasswordHash` applies only once** per instance, and only if predefined accounts still use defaults—see official docs. Existing volumes may require reset or manual password change if the instance was already initialized.

## Blank passwords

Blank passwords are **not** valid with `PasswordHash` (per product documentation).
