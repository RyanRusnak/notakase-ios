import Foundation

/// Seed content, folder ordering and glyphs — ported 1:1 from the design.
public enum SeedData {
    public static let folderOrder = ["Daily", "Notes", "Projects", "notakase.dev"]

    public static let folderGlyph: [String: String] = [
        "Daily": "◷",
        "Notes": "❯",
        "Projects": "◆",
        "notakase.dev": "⬡",
    ]

    public static let notes: [Note] = [
        Note(
            id: "daily-today", folder: "Daily", title: "2026-07-13",
            updated: "just now",
            body: """
                # Thursday, July 13

                A quiet morning. Coffee, then straight into the [[Notakase Spec]].

                ## Focus for today
                - [x] Wire the theme switcher to live CSS variables
                - [x] Draft the *publishing* model
                - [ ] Test vim keybindings in the editor
                - [ ] Write [[Getting Started]] for the docs site

                > The best interface is the one that disappears. Type, and the words are simply *there*.

                ## Notes
                Reading through **Bringhurst** again. The measure — 45 to 75 characters — matters more than the font. Notakase locks the column at a comfortable `66ch`.

                Hit `⌘K` to jump anywhere. `i` to write, `Esc` to think.
                """
        ),
        Note(
            id: "daily-yest", folder: "Daily", title: "2026-07-12",
            updated: "yesterday",
            body: """
                # Wednesday, July 12

                Shipped the two-pane layout. Sidebar feels right at **266px**.

                - [x] Sidebar + note list
                - [x] Status bar with modal indicator
                - [ ] Command palette polish
                """
        ),
        Note(
            id: "omarchy", folder: "Notes", title: "Omarchy Setup",
            updated: "2 days ago",
            body: """
                # Omarchy Setup

                My daily driver on the ThinkPad. Hyprland plus a stack of themes I can swap in a keystroke.

                ## Themes I keep loaded
                1. Tokyo Night — cool and calm, the default
                2. Catppuccin — soft, for long writing sessions
                3. Gruvbox — warm, easy on the eyes at night
                4. Everforest — green, grounding

                ```bash
                # Recolor the whole desktop at once
                omarchy-theme-set tokyo-night
                ```

                The magic is that *everything* recolors together — terminal, editor, and now Notakase.
                """
        ),
        Note(
            id: "keyboard", folder: "Notes", title: "Keyboard Workflow",
            updated: "4 days ago",
            body: """
                # Keyboard Workflow

                Hands stay on the home row.

                ## The essentials
                - `⌘K` — quick switcher
                - `i` and `Esc` — insert and normal mode
                - `j` `k` — move by block
                - `t` — cycle theme

                > You spend far more time reading and navigating than typing.

                Modal editing optimizes for that reality.
                """
        ),
        Note(
            id: "reading", folder: "Notes", title: "Reading List",
            updated: "1 week ago",
            body: """
                # Reading List

                ## In progress
                - [ ] *The Elements of Typographic Style* — Bringhurst
                - [x] *Refactoring UI* — Wathan and Schoger

                ## Someday
                - [ ] *A Pattern Language*
                - [ ] *Thinking with Type*
                """
        ),
        Note(
            id: "spec", folder: "Projects", title: "Notakase Spec",
            updated: "today",
            body: """
                # Notakase Spec

                An opinionated, typography-first markdown editor. Notes *and* a publisher.

                ## Principles
                1. **Keyboard first.** The mouse is optional.
                2. **Typography forward.** A document should look finished while you write it.
                3. **Themes are sacred.** Match Omarchy, exactly.

                ## The publishing idea
                Any top-level folder is a website. Files link to each other with `[[wikilinks]]`, and Notakase resolves them into a navigable static site.

                See [[Publishing]] for the model.

                ![Architecture diagram — vault to static site](diagram)
                """
        ),
        Note(
            id: "site-index", folder: "notakase.dev", title: "Notakase",
            slug: "index", updated: "today",
            body: """
                # Notakase

                A tiny, opinionated notes app that turns a folder of markdown into a website.

                - [[Getting Started]]
                - [[Themes]]
                - [[Publishing]]

                > notes, served omakase.
                """
        ),
        Note(
            id: "site-start", folder: "notakase.dev", title: "Getting Started",
            slug: "getting-started", updated: "today",
            body: """
                # Getting Started

                Install it, point it at a folder, start writing.

                ```bash
                brew install notakase
                notakase ~/notes
                ```

                Everything is a plain `.md` file. Nothing is locked in.

                Next, pick your look in [[Themes]].
                """
        ),
        Note(
            id: "site-themes", folder: "notakase.dev", sub: "guides",
            title: "Themes", slug: "themes", updated: "today",
            body: """
                # Themes

                Notakase ships the Omarchy palette out of the box.

                - **Tokyo Night** — the default
                - **Catppuccin** — soft and warm
                - **Gruvbox** — retro contrast
                - **Everforest** — calm green

                Press `t` to cycle, or `⌘K` then type "theme".
                """
        ),
        Note(
            id: "site-pub", folder: "notakase.dev", sub: "guides",
            title: "Publishing", slug: "publishing", updated: "today",
            body: """
                # Publishing

                Point Notakase at a folder and it becomes a site.

                ## How links work
                Write `[[Getting Started]]` and it resolves to that page. Broken links are flagged as you type.

                ## Build
                ```bash
                notakase build ./notakase.dev --out ./_site
                ```

                The output is static HTML — host it anywhere.
                """
        ),
    ]
}
