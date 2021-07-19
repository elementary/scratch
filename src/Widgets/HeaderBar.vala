// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
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

namespace Scratch.Widgets {
    public class HeaderBar : Hdy.HeaderBar {
        public Gtk.Menu share_menu;
        public Gtk.MenuButton share_app_menu;
        public Gtk.MenuButton app_menu;
        public Gtk.ToggleButton find_button;
        public Gtk.Button templates_button;
        public Code.FormatBar format_bar;
        public Code.ChooseProjectButton choose_project_button;
        public Gtk.Button build_button;
        public Gtk.Button run_button;
        public Gtk.Button stop_button;

        private const string STYLE_SCHEME_HIGH_CONTRAST = "classic";
        private const string STYLE_SCHEME_LIGHT = "solarized-light";
        private const string STYLE_SCHEME_DARK = "solarized-dark";

        public HeaderBar () {
            Object (
                has_subtitle: false,
                show_close_button: true
            );
        }

        construct {
            var app_instance = (Scratch.Application) GLib.Application.get_default ();

            choose_project_button = new Code.ChooseProjectButton () {
                valign = Gtk.Align.CENTER
            };

            var open_button = new Gtk.Button.from_icon_name ("document-open", Gtk.IconSize.LARGE_TOOLBAR);
            open_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_OPEN;
            open_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (open_button.action_name),
                _("Open a file")
            );

            templates_button = new Gtk.Button.from_icon_name ("text-x-generic-template", Gtk.IconSize.LARGE_TOOLBAR);
            templates_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_TEMPLATES;
            templates_button.tooltip_text = _("Project templates");

            var save_button = new Gtk.Button.from_icon_name ("document-save", Gtk.IconSize.LARGE_TOOLBAR);
            save_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_SAVE;
            save_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (save_button.action_name),
                _("Save this file")
            );

            var save_as_button = new Gtk.Button.from_icon_name ("document-save-as", Gtk.IconSize.LARGE_TOOLBAR);
            save_as_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_SAVE_AS;
            save_as_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (save_as_button.action_name),
                _("Save this file with a different name")
            );

            build_button = new Gtk.Button.from_icon_name ("media-playlist-repeat", Gtk.IconSize.LARGE_TOOLBAR);
            build_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_BUILD;
            build_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (build_button.action_name),
                _("Build")
            );

            run_button = new Gtk.Button.from_icon_name ("media-playback-start", Gtk.IconSize.LARGE_TOOLBAR);
            run_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_RUN;
            run_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (run_button.action_name),
                _("Run")
            );

            stop_button = new Gtk.Button.from_icon_name ("media-playback-stop", Gtk.IconSize.LARGE_TOOLBAR);
            stop_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_STOP;
            stop_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (stop_button.action_name),
                _("Stop")
            );

            var revert_button = new Gtk.Button.from_icon_name ("document-revert", Gtk.IconSize.LARGE_TOOLBAR);
            revert_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REVERT;
            revert_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (revert_button.action_name),
                _("Restore this file")
            );

            find_button = new Gtk.ToggleButton ();
            find_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_SHOW_FIND;
            find_button.image = new Gtk.Image.from_icon_name ("edit-find", Gtk.IconSize.LARGE_TOOLBAR);
            find_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (MainWindow.ACTION_PREFIX + MainWindow.ACTION_FIND),
                _("Find…")
            );

            share_menu = new Gtk.Menu ();
            share_app_menu = new Gtk.MenuButton ();
            share_app_menu.image = new Gtk.Image.from_icon_name ("document-export", Gtk.IconSize.LARGE_TOOLBAR);
            share_app_menu.no_show_all = true;
            share_app_menu.tooltip_text = _("Share");
            share_app_menu.set_popup (share_menu);

            var zoom_out_button = new Gtk.Button.from_icon_name ("zoom-out-symbolic", Gtk.IconSize.MENU);
            zoom_out_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_OUT;
            zoom_out_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (zoom_out_button.action_name),
                _("Zoom Out")
            );

            var zoom_default_button = new Gtk.Button.with_label ("100%");
            zoom_default_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_DEFAULT;
            zoom_default_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (zoom_default_button.action_name),
                _("Zoom 1:1")
            );

            var zoom_in_button = new Gtk.Button.from_icon_name ("zoom-in-symbolic", Gtk.IconSize.MENU);
            zoom_in_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ZOOM_IN;
            zoom_in_button.tooltip_markup = Granite.markup_accel_tooltip (
                app_instance.get_accels_for_action (zoom_in_button.action_name),
                _("Zoom In")
            );

            var font_size_grid = new Gtk.Grid ();
            font_size_grid.column_homogeneous = true;
            font_size_grid.hexpand = true;
            font_size_grid.margin = 12;
            font_size_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
            font_size_grid.add (zoom_out_button);
            font_size_grid.add (zoom_default_button);
            font_size_grid.add (zoom_in_button);

            // Intentionally never attached so we can have a non-selected state
            var color_button_none = new Gtk.RadioButton (null);

            var color_button_white = new Gtk.RadioButton.from_widget (color_button_none);
            color_button_white.halign = Gtk.Align.CENTER;
            style_color_button (color_button_white, STYLE_SCHEME_HIGH_CONTRAST);

            var color_button_light = new Gtk.RadioButton.from_widget (color_button_none);
            color_button_light.halign = Gtk.Align.CENTER;
            style_color_button (color_button_light, STYLE_SCHEME_LIGHT);

            var color_button_dark = new Gtk.RadioButton.from_widget (color_button_none);
            color_button_dark.halign = Gtk.Align.CENTER;
            style_color_button (color_button_dark, STYLE_SCHEME_DARK);

            var menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            menu_separator.margin_top = 12;

            var toggle_sidebar_accellabel = new Granite.AccelLabel.from_action_name (
                _("Toggle Sidebar"),
                MainWindow.ACTION_PREFIX + MainWindow.ACTION_TOGGLE_SIDEBAR
            );

            var toggle_sidebar_menuitem = new Gtk.ModelButton ();
            toggle_sidebar_menuitem.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_TOGGLE_SIDEBAR;
            toggle_sidebar_menuitem.get_child ().destroy ();
            toggle_sidebar_menuitem.add (toggle_sidebar_accellabel);

            var preferences_menuitem = new Gtk.ModelButton ();
            preferences_menuitem.text = _("Preferences");
            preferences_menuitem.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_PREFERENCES;

            var menu_grid = new Gtk.Grid ();
            menu_grid.margin_bottom = 3;
            menu_grid.orientation = Gtk.Orientation.VERTICAL;
            menu_grid.width_request = 200;
            menu_grid.attach (font_size_grid, 0, 0, 3, 1);
            menu_grid.attach (color_button_white, 0, 1, 1, 1);
            menu_grid.attach (color_button_light, 1, 1, 1, 1);
            menu_grid.attach (color_button_dark, 2, 1, 1, 1);
            menu_grid.attach (menu_separator, 0, 2, 3, 1);
            menu_grid.attach (toggle_sidebar_menuitem, 0, 3, 3, 1);
            menu_grid.attach (preferences_menuitem, 0, 6, 3);
            menu_grid.show_all ();

            var menu = new Gtk.Popover (null);
            menu.add (menu_grid);

            var app_menu = new Gtk.MenuButton ();
            app_menu.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.tooltip_text = _("Menu");
            app_menu.popover = menu;

            format_bar = new Code.FormatBar () {
                no_show_all = true,
                valign = Gtk.Align.CENTER
            };
            set_custom_title (format_bar);

            pack_start (choose_project_button);
            pack_start (open_button);
            pack_start (templates_button);
            pack_start (save_button);
            pack_start (save_as_button);
            pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            pack_start (build_button);
            pack_start (run_button);
            pack_start (stop_button);
            pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            pack_start (revert_button);
            pack_end (app_menu);
            pack_end (share_app_menu);
            pack_end (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            pack_end (find_button);

            show_all ();

            share_menu.insert.connect (on_share_menu_changed);
            share_menu.remove.connect (on_share_menu_changed);

            Scratch.settings.changed.connect ((key) => {
                if (key != "autosave" && key != "font") {
                    return;
                }

                save_button.visible = !Scratch.settings.get_boolean ("autosave");
                var last_window = app_instance.get_last_window ();
                if (last_window != null) {
                    zoom_default_button.label = "%.0f%%".printf (last_window.get_current_font_size () * 10);
                }
            });

            var gtk_settings = Gtk.Settings.get_default ();

            switch (Scratch.settings.get_string ("style-scheme")) {
                case STYLE_SCHEME_HIGH_CONTRAST:
                    color_button_white.active = true;
                    break;
                case STYLE_SCHEME_LIGHT:
                    color_button_light.active = true;
                    break;
                case STYLE_SCHEME_DARK:
                    color_button_dark.active = true;
                    break;
                default:
                    color_button_none.active = true;
            }

            color_button_dark.clicked.connect (() => {
                Scratch.settings.set_boolean ("prefer-dark-style", true);
                Scratch.settings.set_string ("style-scheme", STYLE_SCHEME_DARK);
                gtk_settings.gtk_application_prefer_dark_theme = true;
            });

            color_button_light.clicked.connect (() => {
                Scratch.settings.set_boolean ("prefer-dark-style", false);
                Scratch.settings.set_string ("style-scheme", STYLE_SCHEME_LIGHT);
                gtk_settings.gtk_application_prefer_dark_theme = false;
            });

            color_button_white.clicked.connect (() => {
                Scratch.settings.set_boolean ("prefer-dark-style", false);
                Scratch.settings.set_string ("style-scheme", STYLE_SCHEME_HIGH_CONTRAST);
                gtk_settings.gtk_application_prefer_dark_theme = false;
            });
        }

        private void style_color_button (Gtk.Widget color_button, string style_id) {
            string background = "#FFF";
            string foreground = "#333";

            var sssm = Gtk.SourceStyleSchemeManager.get_default ();
            if (style_id in sssm.scheme_ids) {
                var scheme = sssm.get_scheme (style_id);
                color_button.tooltip_text = scheme.name;

                var background_style = scheme.get_style ("background-pattern");
                var foreground_style = scheme.get_style ("text");

                if (background_style != null && background_style.background_set && !("rgba" in background_style.background)) {
                    background = background_style.background;
                }

                if (foreground_style != null && foreground_style.foreground_set) {
                    foreground = foreground_style.foreground;
                }
            }

            var style_css = """
                .color-button radio {
                    background-color: %s;
                    color: %s;
                    padding: 10px;
                    -gtk-icon-shadow: none;
                }
            """.printf (background, foreground);

            var css_provider = new Gtk.CssProvider ();

            try {
                css_provider.load_from_data (style_css);
            } catch (Error e) {
                critical ("Unable to style color button: %s", e.message);
            }

            unowned var style_context = color_button.get_style_context ();
            style_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
            style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        private void on_share_menu_changed () {
            if (share_menu.get_children ().length () > 0) {
                share_app_menu.no_show_all = false;
                share_app_menu.visible = true;
                share_app_menu.show_all ();
            } else {
                share_app_menu.no_show_all = true;
                share_app_menu.visible = false;
                share_app_menu.hide ();
            }
        }

        public void document_available (bool has_document) {
            if (has_document) {
                format_bar.no_show_all = false;
                format_bar.show_all ();
            } else {
                format_bar.no_show_all = true;
                format_bar.hide ();
            }
        }

        public void set_document_focus (Scratch.Services.Document doc) {
            format_bar.set_document (doc);
            choose_project_button.set_document (doc);
        }
    }
}
