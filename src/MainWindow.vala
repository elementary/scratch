// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2011–2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017–2018 elementary, Inc. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch {
    public class MainWindow : Gtk.Window {
        public const int FONT_SIZE_MAX = 72;
        public const int FONT_SIZE_MIN = 7;
        private const uint MAX_SEARCH_TEXT_LENGTH = 255;

        public weak Scratch.Application app { get; construct; }

        // Widgets
        public Scratch.Widgets.HeaderBar toolbar;
        private Gtk.Revealer search_revealer;
        public Scratch.Widgets.SearchBar search_bar;
        public Scratch.Widgets.SplitView split_view;
        private FolderManager.FileView folder_manager_view;

        // Plugins
        private Scratch.Services.PluginsManager plugins;

        // Widgets for Plugins
        public Gtk.Notebook bottombar;
        public Code.Pane project_pane;

        private Gtk.Dialog? preferences_dialog = null;
        private Gtk.Paned hp1;
        private Gtk.Paned vp;

        public Gtk.Clipboard clipboard;

#if HAVE_ZEITGEIST
        // Zeitgeist integration
        private Zeitgeist.DataSourceRegistry registry;
#endif

        // Delegates
        delegate void HookFunc ();

        public SimpleActionGroup actions { get; construct; }

        public const string ACTION_PREFIX = "win.";
        public const string ACTION_FIND = "action_find";
        public const string ACTION_FIND_NEXT = "action_find_next";
        public const string ACTION_FIND_PREVIOUS = "action_find_previous";
        public const string ACTION_OPEN = "action_open";
        public const string ACTION_OPEN_FOLDER = "action_open_folder";
        public const string ACTION_COLLAPSE_ALL_FOLDERS = "action_collapse_all_folders";
        public const string ACTION_ORDER_FOLDERS = "action_order_folders";
        public const string ACTION_GO_TO = "action_go_to";
        public const string ACTION_NEW_VIEW = "action_new_view";
        public const string ACTION_SORT_LINES = "action_sort_lines";
        public const string ACTION_NEW_TAB = "action_new_tab";
        public const string ACTION_NEW_FROM_CLIPBOARD = "action_new_from_clipboard";
        public const string ACTION_PREFERENCES = "preferences";
        public const string ACTION_REMOVE_VIEW = "action_remove_view";
        public const string ACTION_UNDO = "action_undo";
        public const string ACTION_REDO = "action_redo";
        public const string ACTION_REVERT = "action_revert";
        public const string ACTION_SAVE = "action_save";
        public const string ACTION_SAVE_AS = "action_save_as";
        public const string ACTION_SHOW_FIND = "action_show_find";
        public const string ACTION_TEMPLATES = "action_templates";
        public const string ACTION_SHOW_REPLACE = "action_show_replace";
        public const string ACTION_TO_LOWER_CASE = "action_to_lower_case";
        public const string ACTION_TO_UPPER_CASE = "action_to_upper_case";
        public const string ACTION_DUPLICATE = "action_duplicate";
        public const string ACTION_FULLSCREEN = "action_fullscreen";
        public const string ACTION_QUIT = "action_quit";
        public const string ACTION_ZOOM_DEFAULT = "action_zoom_default";
        public const string ACTION_ZOOM_IN = "action_zoom_in";
        public const string ACTION_ZOOM_OUT = "action_zoom_out";
        public const string ACTION_TOGGLE_COMMENT = "action_toggle_comment";
        public const string ACTION_TOGGLE_SIDEBAR = "action_toggle_sidebar";

        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const ActionEntry[] ACTION_ENTRIES = {
            { ACTION_FIND, action_fetch },
            { ACTION_FIND_NEXT, action_find_next },
            { ACTION_FIND_PREVIOUS, action_find_previous },
            { ACTION_OPEN, action_open },
            { ACTION_OPEN_FOLDER, action_open_folder },
            { ACTION_COLLAPSE_ALL_FOLDERS, action_collapse_all_folders },
            { ACTION_ORDER_FOLDERS, action_order_folders },
            { ACTION_PREFERENCES, action_preferences },
            { ACTION_REVERT, action_revert },
            { ACTION_SAVE, action_save },
            { ACTION_SAVE_AS, action_save_as },
            { ACTION_SHOW_FIND, action_show_fetch, null, "false" },
            { ACTION_TEMPLATES, action_templates },
            { ACTION_GO_TO, action_go_to },
            { ACTION_NEW_VIEW, action_new_view },
            { ACTION_SORT_LINES, action_sort_lines },
            { ACTION_NEW_TAB, action_new_tab },
            { ACTION_NEW_FROM_CLIPBOARD, action_new_tab_from_clipboard },
            { ACTION_PREFERENCES, action_preferences },
            { ACTION_REMOVE_VIEW, action_remove_view },
            { ACTION_UNDO, action_undo },
            { ACTION_REDO, action_redo },
            { ACTION_SHOW_REPLACE, action_fetch },
            { ACTION_TO_LOWER_CASE, action_to_lower_case },
            { ACTION_TO_UPPER_CASE, action_to_upper_case },
            { ACTION_DUPLICATE, action_duplicate },
            { ACTION_FULLSCREEN, action_fullscreen },
            { ACTION_QUIT, action_quit },
            { ACTION_ZOOM_DEFAULT, action_set_default_zoom },
            { ACTION_ZOOM_IN, action_zoom_in },
            { ACTION_ZOOM_OUT, action_zoom_out},
            { ACTION_TOGGLE_COMMENT, action_toggle_comment },
            { ACTION_TOGGLE_SIDEBAR, action_toggle_sidebar }
        };

        public MainWindow (Scratch.Application scratch_app) {
            Object (
                application: scratch_app,
                app: scratch_app,
                icon_name: Constants.PROJECT_NAME,
                title: _("Code")
            );
        }

        static construct {
            action_accelerators.set (ACTION_FIND, "<Control>f");
            action_accelerators.set (ACTION_FIND_NEXT, "<Control>g");
            action_accelerators.set (ACTION_FIND_PREVIOUS, "<Control><shift>g");
            action_accelerators.set (ACTION_OPEN, "<Control>o");
            action_accelerators.set (ACTION_REVERT, "<Control><shift>o");
            action_accelerators.set (ACTION_SAVE, "<Control>s");
            action_accelerators.set (ACTION_SAVE_AS, "<Control><shift>s");
            action_accelerators.set (ACTION_GO_TO, "<Control>i");
            action_accelerators.set (ACTION_NEW_VIEW, "F3");
            action_accelerators.set (ACTION_SORT_LINES, "F5");
            action_accelerators.set (ACTION_NEW_TAB, "<Control>n");
            action_accelerators.set (ACTION_UNDO, "<Control>z");
            action_accelerators.set (ACTION_REDO, "<Control><shift>z");
            action_accelerators.set (ACTION_SHOW_REPLACE, "<Control>r");
            action_accelerators.set (ACTION_TO_LOWER_CASE, "<Control>l");
            action_accelerators.set (ACTION_TO_UPPER_CASE, "<Control>u");
            action_accelerators.set (ACTION_DUPLICATE, "<Control>d");
            action_accelerators.set (ACTION_FULLSCREEN, "F11");
            action_accelerators.set (ACTION_QUIT, "<Control>q");
            action_accelerators.set (ACTION_ZOOM_DEFAULT, "<Control>0");
            action_accelerators.set (ACTION_ZOOM_DEFAULT, "<Control>KP_0");
            action_accelerators.set (ACTION_ZOOM_IN, "<Control>plus");
            action_accelerators.set (ACTION_ZOOM_IN, "<Control>equal");
            action_accelerators.set (ACTION_ZOOM_IN, "<Control>KP_Add");
            action_accelerators.set (ACTION_ZOOM_OUT, "<Control>minus");
            action_accelerators.set (ACTION_ZOOM_OUT, "<Control>KP_Subtract");
            action_accelerators.set (ACTION_TOGGLE_COMMENT, "<Control>m");
            action_accelerators.set (ACTION_TOGGLE_COMMENT, "<Control>slash");
            action_accelerators.set (ACTION_TOGGLE_SIDEBAR, "F9"); // GNOME
            action_accelerators.set (ACTION_TOGGLE_SIDEBAR, "<Control>backslash"); // Atom

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/code/Application.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        construct {
            actions = new SimpleActionGroup ();
            actions.add_action_entries (ACTION_ENTRIES, this);
            insert_action_group ("win", actions);

            actions.action_state_changed.connect ((name, new_state) => {
                if (name == ACTION_SHOW_FIND) {
                    if (new_state.get_boolean () == false) {
                        toolbar.find_button.tooltip_markup = Granite.markup_accel_tooltip (
                            app.get_accels_for_action (ACTION_PREFIX + ACTION_FIND),
                            _("Find…")
                        );
                    } else {
                        toolbar.find_button.tooltip_markup = Granite.markup_accel_tooltip (
                            {"Escape"},
                            _("Hide search bar")
                        );
                    }

                    search_revealer.set_reveal_child (new_state.get_boolean ());
                }
            });

            foreach (var action in action_accelerators.get_keys ()) {
                var accels_array = action_accelerators[action].to_array ();
                accels_array += null;

                app.set_accels_for_action (ACTION_PREFIX + action, accels_array);
            }

            set_size_request (450, 400);
            set_hide_titlebar_when_maximized (false);

            var rect = Gdk.Rectangle ();
            Scratch.saved_state.get ("window-size", "(ii)", out rect.width, out rect.height);

            default_width = rect.width;
            default_height = rect.height;

            var gtk_settings = Gtk.Settings.get_default ();
            gtk_settings.gtk_application_prefer_dark_theme = Scratch.settings.get_boolean ("prefer-dark-style");

            var window_state = Scratch.saved_state.get_enum ("window-state");
            switch (window_state) {
                case ScratchWindowState.MAXIMIZED:
                    maximize ();
                    break;
                case ScratchWindowState.FULLSCREEN:
                    fullscreen ();
                    break;
                default:
                    Scratch.saved_state.get ("window-position", "(ii)", out rect.x, out rect.y);
                    if (rect.x != -1 && rect.y != -1) {
                        move (rect.x, rect.y);
                    }
                    break;
            }

            clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);

            plugins = new Scratch.Services.PluginsManager (this, app.app_cmd_name.down ());

            key_press_event.connect (on_key_pressed);

            // Set up layout
            init_layout ();
            set_widgets_sensitive (false);

            toolbar.templates_button.visible = (plugins.plugin_iface.template_manager.template_available);
            plugins.plugin_iface.template_manager.notify["template_available"].connect (() => {
                toolbar.templates_button.visible = (plugins.plugin_iface.template_manager.template_available);
            });

            // Restore session
            restore_saved_state_extra ();

            // Crate folder for unsaved documents
            create_unsaved_documents_directory ();

#if HAVE_ZEITGEIST
            // Set up the Data Source Registry for Zeitgeist
            registry = new Zeitgeist.DataSourceRegistry ();

            var ds_event = new Zeitgeist.Event ();
            ds_event.actor = "application://" + Constants.PROJECT_NAME + ".desktop";
            ds_event.add_subject (new Zeitgeist.Subject ());
            var ds_events = new GenericArray<Zeitgeist.Event> ();
            ds_events.add (ds_event);
            var ds = new Zeitgeist.DataSource.full ("code-logger",
                                          _("Zeitgeist Datasource for Code"),
                                          "A data source which logs Open, Close, Save and Move Events",
                                          ds_events); // FIXME: templates!
            registry.register_data_source.begin (ds, null, (obj, res) => {
                try {
                    registry.register_data_source.end (res);
                } catch (Error reg_err) {
                    critical (reg_err.message);
                }
            });
#endif

            Unix.signal_add (Posix.Signal.INT, quit_source_func, Priority.HIGH);
            Unix.signal_add (Posix.Signal.TERM, quit_source_func, Priority.HIGH);

            /* Splitview controls showing and hiding of Welcome view */
        }

        private void init_layout () {
            toolbar = new Scratch.Widgets.HeaderBar ();
            toolbar.title = title;
            set_titlebar (toolbar);

            // SearchBar
            search_bar = new Scratch.Widgets.SearchBar (this);
            search_revealer = new Gtk.Revealer ();
            search_revealer.add (search_bar);

            search_bar.map.connect_after ((w) => { /* signalled when reveal child */
                set_search_text ();
            });
            search_bar.search_entry.unmap.connect_after (() => { /* signalled when reveal child */
                search_bar.set_search_string ("");
                search_bar.highlight_none ();
            });

            Scratch.settings.bind ("cyclic-search", search_bar.tool_cycle_search, "active", SettingsBindFlags.DEFAULT);

            // SlitView
            split_view = new Scratch.Widgets.SplitView (this);

            // Signals
            split_view.welcome_shown.connect (() => {
                toolbar.title = app.app_cmd_name;
                toolbar.document_available (false);
                set_widgets_sensitive (false);
            });

            split_view.welcome_hidden.connect (() => {
                toolbar.document_available (true);
                set_widgets_sensitive (true);
            });

            split_view.document_change.connect ((doc) => {
                plugins.hook_document (doc);

                search_bar.set_text_view (doc.source_view);
                // Update MainWindow title
                if (doc != null) {
                    toolbar.set_document_focus (doc);
                    folder_manager_view.select_path (doc.file.get_path ());
                }

                // Set actions sensitive property
                Utils.action_from_group (ACTION_SAVE_AS, actions).set_enabled (doc.file != null);
                doc.check_undoable_actions ();
            });

            project_pane = new Code.Pane ();

            folder_manager_view = new FolderManager.FileView ();

            project_pane.add_tab (folder_manager_view);
            folder_manager_view.show_all ();

            folder_manager_view.select.connect ((a) => {
                var file = new Scratch.FolderManager.File (a);
                var doc = new Scratch.Services.Document (actions, file.file);

                if (file.is_valid_textfile) {
                    open_document (doc);
                } else {
                    open_binary (file.file);
                }
            });

            folder_manager_view.restore_saved_state ();

            bottombar = new Gtk.Notebook ();
            bottombar.no_show_all = true;
            bottombar.page_removed.connect (() => { on_plugin_toggled (bottombar); });
            bottombar.page_added.connect (() => {
                on_plugin_toggled (bottombar);
            });

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.width_request = 200;
            content.pack_start (search_revealer, false, true, 0);
            content.pack_start (split_view, true, true, 0);

            // Set a proper position for ThinPaned widgets
            int width, height;
            get_size (out width, out height);

            hp1 = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            hp1.position = 180;
            hp1.pack1 (project_pane, false, false);
            hp1.pack2 (content, true, false);

            vp = new Gtk.Paned (Gtk.Orientation.VERTICAL);
            vp.position = (height - 150);
            vp.pack1 (hp1, true, false);
            vp.pack2 (bottombar, false, false);

            add (vp);

            search_revealer.set_reveal_child (false);

            realize.connect (() => {
                // Plugins hook
                HookFunc hook_func = () => {
                    plugins.hook_window (this);
                    plugins.hook_toolbar (toolbar);
                    plugins.hook_share_menu (toolbar.share_menu);
                    plugins.hook_notebook_bottom (bottombar);
                    plugins.hook_split_view (split_view);
                };

                plugins.extension_added.connect (() => {
                    hook_func ();
                });

                hook_func ();
            });

            // Show/Hide widgets
            show_all ();
        }

        private void open_binary (File file) {
            if (!file.query_exists ()) {
                return;
            }

            try {
                AppInfo.launch_default_for_uri (file.get_uri (), null);
            } catch (Error e) {
                critical (e.message);
            }
        }

        public void restore_opened_documents () {
            if (privacy_settings.get_boolean ("remember-recent-files")) {
                var uris_view1 = Scratch.settings.get_strv ("opened-files-view1");
                var uris_view2 = Scratch.settings.get_strv ("opened-files-view2");
                var focused_document1 = Scratch.settings.get_string ("focused-document-view1");
                var focused_document2 = Scratch.settings.get_string ("focused-document-view2");

                if (uris_view1.length > 0) {
                    var view = add_view ();
                    if (!load_files_for_view (view, uris_view1, focused_document1)) {
                        split_view.remove_view (view);
                    }
                }

                if (uris_view2.length > 0) {
                    var view = add_view ();
                    if (!load_files_for_view (view, uris_view2, focused_document2)) {
                        split_view.remove_view (view);
                    }
                }
            }
        }

        private bool load_files_for_view (Scratch.Widgets.DocumentView view, string[] uris, string focused_document) {
            bool anyfile_loaded = false;
            foreach (string uri in uris) {
               if (uri != "") {
                    GLib.File file;
                    if (Uri.parse_scheme (uri) != null) {
                        file = File.new_for_uri (uri);
                    } else {
                        file = File.new_for_commandline_arg (uri);
                    }
                    /* Leave it to doc to handle problematic files properly
                       But for files that do not exist we need to make sure that doc won't create a new file
                    */
                    if (file.query_exists ()) {
                        anyfile_loaded = true;
                        var doc = new Scratch.Services.Document (actions, file);
                        if (doc.exists () || !doc.is_file_temporary) {
                            open_document (doc, view, file.get_uri () == focused_document);
                        }
                    }
                }
            }
            return anyfile_loaded;
        }

        private bool on_key_pressed (Gdk.EventKey event) {
            switch (Gdk.keyval_name (event.keyval)) {
                case "Escape":
                    if (search_revealer.get_child_revealed ()) {
                        var fetch_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
                        fetch_action.set_state (false);
                    }
                    break;
            }

            // propagate this event to child widgets
            return false;
        }

        private void on_plugin_toggled (Gtk.Notebook notebook) {
            var pages = notebook.get_n_pages ();
            notebook.set_show_tabs (pages > 1);
            notebook.no_show_all = (pages == 0);
            notebook.visible = (pages > 0);
        }

        protected override bool delete_event (Gdk.EventAny event) {
            handle_quit ();
            return !check_unsaved_changes ();
        }

        // Set sensitive property for 'delicate' Widgets/GtkActions while
        private void set_widgets_sensitive (bool val) {
            // SearchManager's stuffs
            Utils.action_from_group (ACTION_SHOW_FIND, actions).set_enabled (val);
            Utils.action_from_group (ACTION_GO_TO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_SHOW_REPLACE, actions).set_enabled (val);
            // Toolbar Actions
            Utils.action_from_group (ACTION_SAVE, actions).set_enabled (val);
            Utils.action_from_group (ACTION_SAVE_AS, actions).set_enabled (val);
            Utils.action_from_group (ACTION_UNDO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_REDO, actions).set_enabled (val);
            Utils.action_from_group (ACTION_REVERT, actions).set_enabled (val);
            search_bar.sensitive = val;
            toolbar.share_app_menu.sensitive = val;

            // PlugIns
            if (val) {
                on_plugin_toggled (bottombar);
            }
        }

        // Get current view
        public Scratch.Widgets.DocumentView? get_current_view () {
            var view = (Scratch.Widgets.DocumentView) split_view.get_focus_child ();
            if (view == null) {
                // no view is focused right now, so get last focused
                view = split_view.current_view;
            }
            return view;
        }

        // Get current document
        public Scratch.Services.Document? get_current_document () {
            if (split_view.is_empty ()) {
                return null;
            }
            var view = get_current_view ();
            if (view != null) {
                return view.current_document;
            }
            return null;
        }

        // Get current document if it's focused
        public Scratch.Services.Document? get_focused_document () {
            var view = (Scratch.Widgets.DocumentView) split_view.get_focus_child ();
            if (view != null) {
                return view.current_document;
            }
            return null;
        }

        // Add new view
        public Scratch.Widgets.DocumentView? add_view () {
            return split_view.add_view ();
        }

        public void open_folder (File folder) {
            var foldermanager_file = new FolderManager.File (folder.get_path ());
            folder_manager_view.open_folder (foldermanager_file);
        }

        // Open a document
        public void open_document (Scratch.Services.Document doc, Scratch.Widgets.DocumentView? view_ = null, bool focus = true) {
            while (Gtk.events_pending ()) {
                Gtk.main_iteration ();
            }

            if (split_view.is_empty ()) {
                Scratch.Widgets.DocumentView view = split_view.add_view ();
                view.open_document (doc);
            } else {
                Scratch.Widgets.DocumentView view = view_ ?? get_current_view ();
                view.open_document (doc, focus);
            }
        }

        // Close a document
        public void close_document (Scratch.Services.Document doc) {
            Scratch.Widgets.DocumentView? view = null;
            if (split_view.is_empty ()) {
                view = split_view.add_view ();
            } else {
                view = get_current_view ();
            }
            view.close_document (doc);
        }

        // Return true if there are no documents
        public bool is_empty () {
            return split_view.is_empty ();
        }

        public bool has_temporary_files () {
            try {
                var enumerator = File.new_for_path (app.data_home_folder_unsaved).enumerate_children (FileAttribute.STANDARD_NAME, 0, null);
                for (var fileinfo = enumerator.next_file (null); fileinfo != null; fileinfo = enumerator.next_file (null)) {
                    if (!fileinfo.get_name ().has_suffix ("~")) {
                        return true;
                    }
                }
            } catch (Error e) {
                critical (e.message);
            }

            return false;
        }

        // Check if there no unsaved changes
        private bool check_unsaved_changes () {
            if (!is_empty ()) {
                foreach (var w in split_view.views) {
                    var view = w as Scratch.Widgets.DocumentView;
                    view.is_closing = true;
                    foreach (var doc in view.docs) {
                        if (!doc.do_close (true)) {
                            view.current_document = doc;
                            return false;
                        }
                    }
                }
            }

            return true;
        }

        // Save session informations different from window state
        private void restore_saved_state_extra () {
            // Plugin panes size
            hp1.set_position (Scratch.saved_state.get_int ("hp1-size"));
            vp.set_position (Scratch.saved_state.get_int ("vp-size"));
        }

        private void create_unsaved_documents_directory () {
            var directory = File.new_for_path (app.data_home_folder_unsaved);
            if (!directory.query_exists ()) {
                try {
                    directory.make_directory_with_parents ();
                    debug ("created 'unsaved' directory: %s", directory.get_path ());
                } catch (Error e) {
                    critical ("Unable to create the 'unsaved' directory: '%s': %s", directory.get_path (), e.message);
                }
            }
        }

        private void update_saved_state () {
            // Save window state
            var state = get_window ().get_state ();
            if (Gdk.WindowState.MAXIMIZED in state) {
                Scratch.saved_state.set_enum ("window-state", ScratchWindowState.MAXIMIZED);
            } else if (Gdk.WindowState.FULLSCREEN in state) {
                Scratch.saved_state.set_enum ("window-state", ScratchWindowState.FULLSCREEN);
            } else {
                Scratch.saved_state.set_enum ("window-state", ScratchWindowState.NORMAL);
                // Save window size
                int width, height;
                get_size (out width, out height);
                Scratch.saved_state.set ("window-size", "(ii)", width, height);
            }

            // Save window position
            int x, y;
            get_position (out x, out y);
            Scratch.saved_state.set ("window-position", "(ii)", x, y);

            // Plugin panes size
            Scratch.saved_state.set_int ("hp1-size", hp1.get_position ());
            Scratch.saved_state.set_int ("vp-size", vp.get_position ());
        }

        // SIGTERM/SIGINT Handling
        public bool quit_source_func () {
            action_quit ();
            return false;
        }

        // For exit cleanup
        private void handle_quit () {
            update_saved_state ();
        }

        public void set_default_zoom () {
            Scratch.settings.set_string ("font", get_current_font () + " " + get_default_font_size ().to_string ());
        }

        // Ctrl + scroll
        public void action_zoom_in () {
            zooming (Gdk.ScrollDirection.UP);
        }

        // Ctrl + scroll
        public void action_zoom_out () {
            zooming (Gdk.ScrollDirection.DOWN);
        }

        private void zooming (Gdk.ScrollDirection direction) {
            string font = get_current_font ();
            int font_size = (int) get_current_font_size ();
            if (Scratch.settings.get_boolean ("use-system-font")) {
                Scratch.settings.set_boolean ("use-system-font", false);
                font = get_default_font ();
                font_size = (int) get_default_font_size ();
            }

            if (direction == Gdk.ScrollDirection.DOWN) {
                font_size --;
                if (font_size < FONT_SIZE_MIN) {
                    return;
                }
            } else if (direction == Gdk.ScrollDirection.UP) {
                font_size ++;
                if (font_size > FONT_SIZE_MAX) {
                    return;
                }
            }

            string new_font = font + " " + font_size.to_string ();
            Scratch.settings.set_string ("font", new_font);
        }

        public string get_current_font () {
            string font = Scratch.settings.get_string ("font");
            string font_family = font.substring (0, font.last_index_of (" "));
            return font_family;
        }

        public double get_current_font_size () {
            string font = Scratch.settings.get_string ("font");
            string font_size = font.substring (font.last_index_of (" ") + 1);
            return double.parse (font_size);
        }

        public string get_default_font () {
            string font = app.default_font;
            string font_family = font.substring (0, font.last_index_of (" "));
            return font_family;
        }

        public double get_default_font_size () {
            string font = app.default_font;
            string font_size = font.substring (font.last_index_of (" ") + 1);
            return double.parse (font_size);
        }

        // Actions functions
        private void action_set_default_zoom () {
            set_default_zoom ();
        }

        private void action_preferences () {
            if (preferences_dialog == null) {
                preferences_dialog = new Scratch.Dialogs.Preferences (this, plugins);
                preferences_dialog.show_all ();

                preferences_dialog.destroy.connect (() => {
                    preferences_dialog = null;
                });
            }

            preferences_dialog.present ();
        }

        private void action_quit () {
            handle_quit ();
            if (check_unsaved_changes ()) {
                destroy ();
            }
        }

        private void action_open () {
            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.set_filter_name (_("All files"));
            all_files_filter.add_pattern ("*");

            var text_files_filter = new Gtk.FileFilter ();
            text_files_filter.set_filter_name (_("Text files"));
            text_files_filter.add_mime_type ("text/*");

            var file_chooser = new Gtk.FileChooserNative (
                _("Open some files"),
                this,
                Gtk.FileChooserAction.OPEN,
                _("Open"),
                _("Cancel")
            );
            file_chooser.add_filter (text_files_filter);
            file_chooser.add_filter (all_files_filter);
            file_chooser.select_multiple = true;
            file_chooser.set_current_folder_uri (Utils.last_path ?? GLib.Environment.get_home_dir ());

            var response = file_chooser.run ();
            file_chooser.destroy (); // Close now so it does not stay open during lengthy or failed loading

            if (response == Gtk.ResponseType.ACCEPT) {
                foreach (string uri in file_chooser.get_uris ()) {
                    // Update last visited path
                    Utils.last_path = Path.get_dirname (uri);
                    // Open the file
                    var file = File.new_for_uri (uri);
                    var doc = new Scratch.Services.Document (actions, file);
                    open_document (doc);
                }
            }
        }

        private void action_open_folder () {
            var chooser = new Gtk.FileChooserNative (
                "Select a folder.", this, Gtk.FileChooserAction.SELECT_FOLDER,
                _("_Open"),
                _("_Cancel")
            );

            chooser.select_multiple = true;

            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                chooser.get_files ().foreach ((glib_file) => {
                    var foldermanager_file = new FolderManager.File (glib_file.get_path ());
                    folder_manager_view.open_folder (foldermanager_file);
                });
            }

            chooser.destroy ();
        }

        private void action_collapse_all_folders () {
            folder_manager_view.collapse_all ();
        }

        private void action_order_folders () {
            folder_manager_view.order_folders ();
        }

        private void action_save () {
            var doc = get_current_document (); /* may return null */
            if (doc != null) {
                if (doc.is_file_temporary == true) {
                    action_save_as ();
                } else {
                    doc.save.begin ();
                }
            }
        }

        private void action_save_as () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.save_as.begin ();
            }
        }

        private void action_undo () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.undo ();
            }
        }

        private void action_redo () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.redo ();
            }
        }

        private void action_revert () {
            var confirmation_dialog = new Scratch.Dialogs.RestoreConfirmationDialog (this);
            if (confirmation_dialog.run () == Gtk.ResponseType.ACCEPT) {
                var doc = get_current_document ();
                if (doc != null) {
                    doc.revert ();
                }
            }
            confirmation_dialog.destroy ();
        }

        private void action_duplicate () {
            var doc = get_current_document ();
            if (doc != null) {
                doc.duplicate_selection ();
            }
        }

        private void action_new_tab () {
            Scratch.Widgets.DocumentView? view = null;
            if (split_view.is_empty ()) {
                view = split_view.add_view ();
            } else {
                view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            }

            view.new_document ();
        }

        private void action_new_tab_from_clipboard () {
            Scratch.Widgets.DocumentView? view = null;
            if (split_view.is_empty ()) {
                view = split_view.add_view ();
            } else {
                view = split_view.get_focus_child () as Scratch.Widgets.DocumentView;
            }

            string text_from_clipboard = clipboard.wait_for_text ();
            view.new_document_from_clipboard (text_from_clipboard);
        }

        private void action_new_view () {
            var view = split_view.add_view ();
            if (view != null) {
                view.new_document ();
            }
        }

        private void action_remove_view () {
            split_view.remove_view ();
        }

        private void action_fullscreen () {
            if (Gdk.WindowState.FULLSCREEN in get_window ().get_state ()) {
                unfullscreen ();
            } else {
                fullscreen ();
            }
        }

        /** Not a toggle action - linked to keyboard short cut (Ctrl-f). **/
        private void action_fetch () {
            if (!search_revealer.child_revealed) {
                var fetch_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
                if (fetch_action.enabled) {
                    /* Toggling the fetch action causes this function to be called again but the search_revealer child
                     * is still not revealed so nothing more happens.  We use the map signal on the search entry
                     * to set it up once it has been revealed. */
                    fetch_action.set_state (true);
                }
            } else {
                set_search_text ();
            }
        }

        private void action_find_next () {
            search_bar.search_next ();
        }

        private void action_find_previous () {
            search_bar.search_previous ();
        }

        private void set_search_text () {
            var current_doc = get_current_document ();
            // This is also called when all documents are closed.
            if (current_doc != null) {
                var selected_text = current_doc.get_selected_text ();
                if (selected_text != "" && selected_text.length < MAX_SEARCH_TEXT_LENGTH) {
                    search_bar.set_search_string (selected_text);
                }

                search_bar.search_entry.grab_focus (); /* causes loss of document selection */

                if (selected_text != "") {
                    search_bar.search_next (); /* this selects the next match (if any) */
                }

            }
        }

        /** Toggle action - linked to toolbar togglebutton. **/
        private void action_show_fetch () {
            var fetch_action = Utils.action_from_group (ACTION_SHOW_FIND, actions);
            fetch_action.set_state (!fetch_action.get_state ().get_boolean ());
        }

        private void action_go_to () {
            toolbar.format_bar.line_toggle.active = true;
        }

        private void action_templates () {
            plugins.plugin_iface.template_manager.show_window (this);
        }

        private void action_to_lower_case () {
            var doc = get_focused_document ();
            if (doc == null) {
                return;
            }

            var buffer = doc.source_view.buffer;
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_text (start, end, true);

            buffer.delete (ref start, ref end);
            buffer.insert (ref start, selected.down (), -1);
        }

        private void action_to_upper_case () {
            var doc = get_focused_document ();
            if (doc == null) {
                return;
            }

            var buffer = doc.source_view.buffer;
            Gtk.TextIter start, end;
            buffer.get_selection_bounds (out start, out end);
            string selected = buffer.get_text (start, end, true);

            buffer.delete (ref start, ref end);
            buffer.insert (ref start, selected.up (), -1);
        }

        private void action_toggle_comment () {
            var doc = get_focused_document ();
            if (doc == null) {
                return;
            }

            var buffer = doc.source_view.buffer;
            if (buffer is Gtk.SourceBuffer) {
                CommentToggler.toggle_comment (buffer as Gtk.SourceBuffer);
            }
        }

        private void action_sort_lines () {
            var doc = get_focused_document ();
            if (doc == null) {
                return;
            }

            doc.source_view.sort_selected_lines ();
        }

        private void action_toggle_sidebar () {
            if (project_pane == null) {
                return;
            }

            project_pane.visible = !project_pane.visible;
        }
    }
}
