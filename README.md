# StARAPTOR: Empowering Player Voices in Game Development Pipelines via LLM-Powered Feature Extraction, Association Mining, and Player Count Forecasting

Repository for the Bachelor's Thesis by **Alfonso Maria Vicidomini**, University of Salerno (Department of Computer Science).

## Cloning the Repository

This repository uses a Git submodule for the underlying LaTeX template. Clone with:

```bash
git clone --recurse-submodules <repo-url>
```

Or, if already cloned:

```bash
git submodule update --init
```

## Compilation

You can compile the thesis using `latexmk` (recommended):

```bash
latexmk -pdf main.tex
```

During compilation, institutional front matter (`covermatter/frontespizio.tex`, etc.) is dynamically generated from the `template/` submodule using the clear-text mapping defined in [`substitutions.json`](substitutions.json).

## Licensing & Attribution

- **Thesis Content:** Copyright (c) 2026 Alfonso Maria Vicidomini. All original thesis writing (`capitoli/`, `references.bib`, personal `covermatter/`) is licensed under the [Creative Commons Attribution 4.0 International (CC BY 4.0)](LICENSE).
- **Template:** The document structure is based on the [SeSaLabUnisa/Template-tesi](https://github.com/SeSaLabUnisa/Template-tesi) template by the SeSa Lab (University of Salerno), included as a submodule in `template/`. Institutional front matter and styles are dynamically compiled from the template at build time.
- **Third-Party Files:** Class and style files provided via the template submodule (e.g. `IEEEtran.cls`, `fncychap.sty`, `utils.sty`) retain their respective original licenses.
