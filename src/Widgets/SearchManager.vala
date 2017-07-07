/*
 * Copyright (C) 2011-2012 Lucas Baudin <xapantu@gmail.com>
 *               2013      Mario Guerriero <mario@elementaryos.org>
 *
 * This file is part of Scratch.
 *
 * Scratch is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Scratch is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Scratch.Widgets {
    public class SearchManager : Gtk.Toolbar {
        // Parent window
        private weak MainWindow window;

        private Gtk.ToolItem tool_search_entry;
        private Gtk.ToolItem tool_replace_entry;
        private Gtk.ToolItem tool_go_to;
        private Gtk.ToolButton tool_arrow_up;
        private Gtk.ToolButton tool_arrow_down;

        /**
         * Is the search cyclic? e.g., when you are at the bottom, if you press
         * "Down", it will go at the start of the file to search for the content
         * of the search entry.
         **/
        private Gtk.ToggleToolButton tool_cycle_search;

        public Gtk.SearchEntry search_entry;
        public Gtk.SearchEntry replace_entry;
        public Gtk.SpinButton go_to_entry;
        private Gtk.Adjustment go_to_adj;

        private Gtk.ToolButton replace_tool_button;
        private Gtk.ToolButton replace_all_tool_button;

        private Scratch.Widgets.SourceView? text_view = null;
        private Gtk.TextBuffer? text_buffer = null;
        private Gtk.SourceSearchContext search_context = null;

        /* The normal color for GtkEntry, used when we put the text in red
         * (when something is not found), and/or we want to re-put the normal
         * color
         */
        private Gdk.RGBA normal_color;

        public signal void need_hide ();

        /**
         * Create a new SearchManager object.
         *
         * following actions : Fetch, ShowGoTo, ShowRreplace, or null.
         **/
        public SearchManager (MainWindow window) {
            // Main entries
            // Search entry
            this.window = window;
            icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Find");
            search_entry.width_request = 250;

            // Replace entry
            replace_entry = new Gtk.SearchEntry ();
            replace_entry.placeholder_text = _("Replace With");
            replace_entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "edit-symbolic");
            replace_entry.width_request = 250;

            // Go To entry
            go_to_adj = new Gtk.Adjustment (0, 0, 1000, 1, 40, 0);
            go_to_entry = new Gtk.SpinButton (go_to_adj, 1, 1);
            go_to_entry.digits = 0;

            // GtkToolItems
            tool_search_entry = new Gtk.ToolItem ();
            tool_arrow_down = new Gtk.ToolButton (null, null);
            tool_arrow_down.icon_name = "go-down-symbolic";
            tool_arrow_down.clicked.connect (search_next);
            tool_arrow_down.sensitive = false;
            tool_arrow_down.margin_start = 3;
            tool_arrow_down.tooltip_text = _("Search next");
            tool_arrow_up = new Gtk.ToolButton (null, null);
            tool_arrow_up.icon_name = "go-up-symbolic";
            tool_arrow_up.clicked.connect (search_previous);
            tool_arrow_up.sensitive = false;
            tool_arrow_up.margin_end = 3;
            tool_arrow_up.tooltip_text = _("Search previous");
            tool_replace_entry = new Gtk.ToolItem ();
            tool_go_to = new Gtk.ToolItem ();

            tool_cycle_search = new Gtk.ToggleToolButton ();
            tool_cycle_search.margin_end = tool_cycle_search.margin_start = 3;
            tool_cycle_search.icon_name = "media-playlist-repeat-symbolic";
            tool_cycle_search.tooltip_text = _("Cyclic Search");

            // Replace GtkToolButton
            replace_tool_button = new Gtk.ToolButton (null, _("Replace"));
            replace_tool_button.margin_start = 3;
            replace_tool_button.clicked.connect (on_replace_entry_activate);

            // Replace all GtkToolButton
            replace_all_tool_button = new Gtk.ToolButton (null, _("Replace all"));
            replace_all_tool_button.clicked.connect (on_replace_all_entry_activate);

            // Populate GtkToolItems
            tool_search_entry.add (search_entry);
            tool_replace_entry.add (replace_entry);
            var go_to_grid = new Gtk.Grid ();
            go_to_grid.orientation = Gtk.Orientation.HORIZONTAL;
            go_to_grid.column_spacing = 6;
            go_to_grid.add (new Gtk.Label (_("Go To Line:")));
            go_to_grid.add (go_to_entry);
            tool_go_to.add (go_to_grid);

            // Connecting to some signals
            search_entry.changed.connect (on_search_entry_text_changed);
            search_entry.key_press_event.connect (on_search_entry_key_press);
            search_entry.focus_in_event.connect (on_search_entry_focused_in);
            search_entry.icon_release.connect ((p0, p1) => {
                if (p0 == Gtk.EntryIconPosition.PRIMARY) {
                    search_next ();
                }
            });
            go_to_entry.activate.connect (on_go_to_entry_activate);
            replace_entry.activate.connect (on_replace_entry_activate);
            replace_entry.key_press_event.connect (on_replace_entry_key_press);

            // Get default text color in Gtk.Entry
            var entry_context = new Gtk.StyleContext ();
            var entry_path = new Gtk.WidgetPath ();
            entry_path.append_type (typeof (Gtk.Widget));
            entry_context.set_path (entry_path);
            entry_context.add_class ("entry");
            normal_color = entry_context.get_color (Gtk.StateFlags.FOCUSED);

            // Add everything to SearchManager's toolbar
            this.add (tool_search_entry);
            this.add (tool_arrow_down);
            this.add (tool_arrow_up);
            this.add (tool_cycle_search);
            this.add (tool_replace_entry);
            this.add (replace_tool_button);
            this.add (replace_all_tool_button);
            var spacer = new Gtk.ToolItem ();
            spacer.set_expand (true);
            this.add (spacer);
            this.add (tool_go_to);

            update_replace_tool_sensitivities (search_entry.text, false);
        }

        public void set_text_view (Scratch.Widgets.SourceView? text_view) {
            if (text_view == null) {
                warning ("No SourceView is associated with SearchManager!");
                return;
            }

            if (this.text_view != null) {
                this.text_buffer.modified_changed.disconnect (on_text_buffer_modified);
            }

            this.text_view = text_view;
            this.text_buffer = text_view.get_buffer ();
            this.search_context = new Gtk.SourceSearchContext (text_buffer as Gtk.SourceBuffer, null);
            search_context.settings.wrap_around = tool_cycle_search.active;
            search_context.settings.regex_enabled = false;

            // Determine the search entry color
            bool found = (search_entry.text != "" && search_entry.text in this.text_buffer.text);
            if (found) {
                tool_arrow_down.sensitive = true;
                tool_arrow_up.sensitive = false;
                search_entry.override_color (Gtk.StateFlags.NORMAL, normal_color);
            } else {
                if (search_entry.text != "") {
                    search_entry.override_color (Gtk.StateFlags.NORMAL, {1.0, 0.0, 0.0, 1.0});
                }

                tool_arrow_down.sensitive = false;
                tool_arrow_up.sensitive = false;
            }

            update_go_to_entry ();
            this.text_buffer.modified_changed.connect (on_text_buffer_modified);
        }

        private void on_go_to_entry_activate () {
            if (text_view != null) {
                text_view.go_to_line (int.parse (go_to_entry.text));
            }
        }

        private void on_replace_entry_activate () {
            if (text_buffer == null) {
                warning ("No valid buffer to replace");
                return;
            }

            Gtk.TextIter? start_iter, end_iter;
            text_buffer.get_iter_at_offset (out start_iter, text_buffer.cursor_position);

            if (search_for_iter (start_iter, out end_iter)) {
                string replace_string = replace_entry.text;
                try {
                    search_context.replace (start_iter, end_iter, replace_string, replace_string.length);
                    bool matches = search ();
                    update_replace_tool_sensitivities (search_entry.text, matches);
                    update_tool_arrows (search_entry.text);
                    debug ("Replace \"%s\" with \"%s\"", search_entry.text, replace_entry.text);
                } catch (Error e) {
                    critical (e.message);
                }
            }
        }

        private void on_replace_all_entry_activate () {
            if (text_buffer == null || this.window.get_current_document () == null) {
                debug ("No valid buffer to replace");
                return;
            }

            string replace_string = replace_entry.text;
            this.window.get_current_document ().toggle_changed_handlers (false);
            try {
                search_context.replace_all (replace_string, replace_string.length);
                update_tool_arrows (search_entry.text);
                update_replace_tool_sensitivities (search_entry.text, false);
            } catch (Error e) {
                critical (e.message);
            }

            this.window.get_current_document ().toggle_changed_handlers (true);
        }

        public void set_search_string (string to_search) {
            search_entry.text = to_search;
        }

        private void on_search_entry_text_changed () {
            var search_string = search_entry.text;
            search_context.settings.search_text = search_string;
            bool case_sensitive = !((search_string.up () == search_string) || (search_string.down () == search_string));
            search_context.settings.case_sensitive = case_sensitive;

            bool matches = search ();
            update_replace_tool_sensitivities (search_entry.text, matches);
            update_tool_arrows (search_entry.text);
        }

        private void update_replace_tool_sensitivities (string search_text, bool matches) {
            replace_tool_button.sensitive = matches && search_text != "";
            replace_all_tool_button.sensitive = matches && search_text != "";
        }

        private bool on_search_entry_focused_in (Gdk.EventFocus event) {
            Gtk.TextIter? start_iter, end_iter;
            text_buffer.get_iter_at_offset (out start_iter, text_buffer.cursor_position);

            end_iter = start_iter;
            bool case_sensitive = !((search_entry.text.up () == search_entry.text) || (search_entry.text.down () == search_entry.text));
            bool found = start_iter.forward_search (search_entry.text,
                                                    case_sensitive ? 0 : Gtk.TextSearchFlags.CASE_INSENSITIVE,
                                                    out start_iter, out end_iter, null);
            if (found) {
                search_entry.override_color (Gtk.StateFlags.FOCUSED, normal_color);
                return true;
            } else {
                if (search_entry.text != "") {
                    search_entry.override_color (Gtk.StateFlags.FOCUSED, {1.0, 0.0, 0.0, 1.0});
                }

                return false;
            }
        }

        public bool search () {
            /* So, first, let's check we can really search something. */
            string search_string = search_entry.text;
            search_context.highlight = false;

            if (text_buffer == null || text_buffer.text == "" || search_string == "") {
                debug ("Can't search anything in an inexistant buffer and/or without anything to search.");
                return false;
            }

            search_context.highlight = true;

            Gtk.TextIter? start_iter, end_iter;
            text_buffer.get_iter_at_offset (out start_iter, text_buffer.cursor_position);

            if (search_for_iter (start_iter, out end_iter)) {
                search_entry.override_color (Gtk.StateFlags.FOCUSED, normal_color);
            } else {
                text_buffer.get_start_iter (out start_iter);
                if (search_for_iter (start_iter, out end_iter)) {
                    search_entry.override_color (Gtk.StateFlags.FOCUSED, normal_color);
                } else {
                    warning ("Not found : \"%s\"", search_string);
                    start_iter.set_offset (-1);
                    text_buffer.select_range (start_iter, start_iter);
                    search_entry.override_color (Gtk.StateFlags.FOCUSED, {1.0, 0.0, 0.0, 1.0});
                    return false;
                }
            }

            return true;
        }

        public void highlight_none () {
            search_context.highlight = false;
        }

        private bool search_for_iter (Gtk.TextIter? start_iter, out Gtk.TextIter? end_iter) {
            end_iter = start_iter;
            bool found = search_context.forward (start_iter, out start_iter, out end_iter);
            if (found) {
                text_buffer.select_range (start_iter, end_iter);
                text_view.scroll_to_iter (start_iter, 0, false, 0, 0);
            }

            return found;
        }

        private bool search_for_iter_backward (Gtk.TextIter? start_iter, out Gtk.TextIter? end_iter) {
            end_iter = start_iter;
            bool found = search_context.backward (start_iter, out start_iter, out end_iter);
            if (found) {
                text_buffer.select_range (start_iter, end_iter);
                text_view.scroll_to_iter (start_iter, 0, false, 0, 0);
            }

            return found;
        }

        public void search_previous () {
            /* Get selection range */
            Gtk.TextIter? start_iter, end_iter;
            if (text_buffer != null) {
                string search_string = search_entry.text;
                text_buffer.get_selection_bounds (out start_iter, out end_iter);
                if(!search_for_iter_backward (start_iter, out end_iter) && tool_cycle_search.active) {
                    text_buffer.get_end_iter (out start_iter);
                    search_for_iter_backward (start_iter, out end_iter);
                }

                update_tool_arrows (search_string);
            }
        }

        public void search_next () {
            /* Get selection range */
            Gtk.TextIter? start_iter, end_iter, end_iter_tmp;
            if (text_buffer != null) {
                string search_string = search_entry.text;
                text_buffer.get_selection_bounds (out start_iter, out end_iter);
                if(!search_for_iter (end_iter, out end_iter_tmp) && tool_cycle_search.active) {
                    text_buffer.get_start_iter (out start_iter);
                    search_for_iter (start_iter, out end_iter);
                }

                update_tool_arrows (search_string);
            }
        }

        private void update_tool_arrows (string search_string) {
            /* We don't need to compute the sensitive states of these widgets
             * if they don't exist. */
            if (tool_arrow_up != null && tool_arrow_down != null) {
                if (search_string == "") {
                    tool_arrow_up.sensitive = false;
                    tool_arrow_down.sensitive = false;
                } else {
                    Gtk.TextIter? start_iter, end_iter;
                    Gtk.TextIter? tmp_start_iter, tmp_end_iter;

                    bool is_in_start, is_in_end;

                    text_buffer.get_start_iter (out tmp_start_iter);
                    text_buffer.get_end_iter (out tmp_end_iter);

                    text_buffer.get_selection_bounds (out start_iter, out end_iter);

                    is_in_start = start_iter.compare(tmp_start_iter) == 0;
                    is_in_end = end_iter.compare(tmp_end_iter) == 0;

                    if (!is_in_end) {
                        bool next_found = search_context.forward (end_iter, out tmp_start_iter, out tmp_end_iter);
                        tool_arrow_down.sensitive = next_found;
                    } else {
                        tool_arrow_down.sensitive = false;
                    }

                    if (!is_in_start) {
                        bool previous_found = search_context.backward (start_iter, out tmp_start_iter, out end_iter);
                        tool_arrow_up.sensitive = previous_found;
                    } else {
                        tool_arrow_up.sensitive = false;
                    }
                }
            }
        }

        private bool on_search_entry_key_press (Gdk.EventKey event) {
            /* We don't need to perform search if there is nothing to search... */
            if (search_entry.text == "") {
                return false;
            }

            string key = Gdk.keyval_name (event.keyval);
            if (event.state == Gdk.ModifierType.SHIFT_MASK) {
                key = "<Shift>" + key;
            }

            switch (key) {
                case "<Shift>Return":
                case "Up":
                    search_previous ();
                    return true;
                case "Return":
                case "Down":
                    search_next ();
                    return true;
                case "Escape":
                    text_view.grab_focus ();
                    return true;
                case "Tab":
                    if (search_entry.is_focus) {
                        replace_entry.grab_focus ();
                    }

                    return true;
            }

            return false;
        }

        private bool on_replace_entry_key_press (Gdk.EventKey event) {
            /* We don't need to perform search if there is nothing to search… */
            if (search_entry.text == "") {
                return false;
            }

            switch (Gdk.keyval_name (event.keyval)) {
                case "Up":
                    search_previous ();
                    return true;
                case "Down":
                    search_next ();
                    return true;
                case "Escape":
                    text_view.grab_focus ();
                    return true;
                case "Tab":
                    if (replace_entry.is_focus) {
                        go_to_entry.grab_focus ();
                    }

                    return true;
            }

            return false;
        }

        private void update_go_to_entry () {
            //Set the maximum range of the "Go To Line" spinbutton.
            go_to_entry.set_range (1, text_buffer.get_line_count ());
        }

        private void on_text_buffer_modified () {
            update_go_to_entry ();
        }
    }
}
