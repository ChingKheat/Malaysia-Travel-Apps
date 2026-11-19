# Open Code Review

[Open Code Review](https://github.com/alibaba/open-code-review) is an AI-assisted code review CLI. It selects changed files from Git and asks a configured model to inspect them. Review its findings against the code before making changes.

## Installation on Windows

This project was set up with the official Windows AMD64 release `v1.13.13`, installed at `.dart_tool/open-code-review/v1.13.13/ocr.exe`. The `.dart_tool` directory is ignored by Git and may be cleared by Flutter tooling. Git 2.41 or later is required. The static binary does not require npm, Python, Docker, or Go.

To reproduce the installation, download `opencodereview-windows-amd64.exe` and `sha256sum.txt` from the [v1.13.13 release](https://github.com/alibaba/open-code-review/releases/tag/v1.13.13). Compare the executable's SHA-256 hash with its entry in the checksum file before placing it at the path above. Avoid overwriting an existing installation without checking it first.

```powershell
Get-FileHash .\.dart_tool\open-code-review\v1.13.13\ocr.exe -Algorithm SHA256
Get-Content .\.dart_tool\open-code-review\v1.13.13\sha256sum.txt | Select-String 'opencodereview-windows-amd64.exe'
.\.dart_tool\open-code-review\v1.13.13\ocr.exe version
```

## Model configuration

An independent OCR review requires access to a supported model endpoint. The built-in providers include OpenAI, Anthropic and Alibaba DashScope. Their documented environment variables are `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` and `DASHSCOPE_API_KEY`, respectively. Choose a provider and model that supports tool calling, and consult its pricing and data-handling terms before use. Code and surrounding context may be sent to that provider.

The interactive setup is `ocr config provider` followed by `ocr config model`; OCR stores configuration in the user profile. Check for existing configuration before using it. For supported built-in providers, OCR can use the relevant environment variable when no key is stored in its configuration. Do not put credentials in project files, command history, reports, or Git. Configuration and API connectivity have not yet been verified for this installation.

## Review changes

In Codex, ask: "Use Open Code Review to review my current Git changes and explain the findings." Codex can run the installed executable and check the output for you. A separately configured model provides an independent OCR review. OCR's delegation mode instead has the host agent perform the review; it does not require an OCR API key, but is not a separate model review.

From the project root in PowerShell:

```powershell
git diff
& .\.dart_tool\open-code-review\v1.13.13\ocr.exe review --preview
& .\.dart_tool\open-code-review\v1.13.13\ocr.exe review
```

The preview shows selected and excluded files without calling a model. Workspace review considers staged, unstaged and untracked changes, subject to OCR's filters. Review the preview and any warnings: files may be excluded, oversized, or otherwise skipped. At setup, the preview selected Dart and SQL changes but excluded ARB and Markdown files; it also selected generated Dart localization files. Review excluded files separately when relevant. Use `ocr review --help` for output, provider, model and exclusion options.

Review comments are suggestions, not proof that an issue exists or that the remaining code is safe. Confirm each finding against callers, tests and project requirements. Decide which findings to approve, ask Codex to implement approved fixes, rerun the review, and run `flutter test` before committing.

## Troubleshooting

- If the executable is missing, repeat the pinned installation and checksum check above. Run it from the project root.
- If a review cannot connect, check the selected provider, model, API credential, network access and provider account. Do not share the credential in chat or logs.
- If a file is absent from the preview, inspect its exclusion reason and review it separately or consult the [rules documentation](https://github.com/alibaba/open-code-review/blob/main/pages/src/content/docs/en/review-rules.md).
- An API-backed review may cost money and can miss defects or produce false positives. Check warnings and partial results rather than assuming complete coverage.
