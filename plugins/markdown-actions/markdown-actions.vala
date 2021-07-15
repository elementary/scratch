// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2020 Igor Montagner <igordsm@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

public class Code.Plugins.MarkdownActions : Peas.ExtensionBase, Peas.Activatable {
    Scratch.Widgets.SourceView current_source;
    Scratch.Services.Interface plugins;

    public Object object { owned get; construct; }

    public void update_state () {}

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((doc) => {
            if (current_source != null) {
                current_source.key_press_event.disconnect (shortcut_handler);
                current_source.notify["language"].disconnect (configure_shortcuts);
            }

            current_source = doc.source_view;
            configure_shortcuts ();

            current_source.notify["language"].connect (configure_shortcuts);
        });
    }

    private void configure_shortcuts () {
        var lang = current_source.language;
        if (lang != null && lang.id == "markdown") {
            current_source.key_press_event.connect (shortcut_handler);
        } else {
            current_source.key_press_event.disconnect (shortcut_handler);
        }
    }

    private bool shortcut_handler (Gdk.EventKey evt) {
        var control = (evt.state & Gdk.ModifierType.CONTROL_MASK) != 0;
        var shift = (evt.state & Gdk.ModifierType.SHIFT_MASK) != 0;
        var other_mods = (evt.state & Gtk.accelerator_get_default_mod_mask () &
                          ~Gdk.ModifierType.SHIFT_MASK &
                          ~Gdk.ModifierType.CONTROL_MASK) != 0;

        if (evt.is_modifier == 1 || other_mods == true) {
            return false;
        }

        if (control && shift) {
            switch (evt.keyval) {
                case Gdk.Key.B:
                    add_markdown_tag ("**");
                    return true;
                case Gdk.Key.I:
                    add_markdown_tag ("_");
                    return true;
                case Gdk.Key.K:
                    insert_link ();
                    break;
            }
        }

        if (evt.keyval == Gdk.Key.Return) {
            char ul_marker;
            int ol_number = 1;
            string item_text;
            var line = get_current_line ();
            if (parse_unordered_list_item (line, out ul_marker)) {
                if (line.length <= 3) { // empty item
                    delete_empty_item ();
                } else {
                    string to_insert = "\n%c ".printf (ul_marker);
                    current_source.buffer.insert_at_cursor (to_insert, to_insert.length);
                }
                return true;
            } else if (parse_ordered_list_item (line, ref ol_number, out item_text)) {
                if (item_text.length == 0) {
                    delete_empty_item ();
                } else {
                    string to_insert = "\n%d. ".printf (ol_number + 1);
                    current_source.buffer.insert_at_cursor (to_insert, to_insert.length);
                    fix_ordered_list_numbering ();
                }
                return true;
            }
        }
        return false;
    }

    private void delete_empty_item () {
        Gtk.TextIter start, end;
        var current_buffer = current_source.buffer;
        current_buffer.get_iter_at_offset (out start, current_buffer.cursor_position);
        start.backward_chars (start.get_line_offset ());
        end = start;
        end.forward_to_line_end ();
        current_buffer.delete (ref start, ref end);
        current_buffer.insert_at_cursor ("\n", 1);
    }

    private void fix_ordered_list_numbering () {
        Gtk.TextIter next;
        var current_buffer = current_source.buffer;
        current_buffer.get_iter_at_offset (out next, current_buffer.cursor_position);
        var line = get_current_line (next).strip ();
        int count = 1;
        string item_text;
        parse_ordered_list_item (line, ref count, out item_text);

        while (next.forward_line ()) {
            count++;
            line = get_current_line (next).strip ();
            if (line.length == 0) {
                break;
            }

            var next_mark = current_buffer.create_mark (null, next, true);
            var point_offset = line.index_of_char ('.');
            var start = next;
            var end = start;
            end.forward_chars (point_offset);

            current_buffer.delete (ref start, ref end);
            current_buffer.get_iter_at_mark (out next, next_mark);

            var to_insert = "%d".printf (count);
            current_buffer.insert (ref next, to_insert, to_insert.length);
        }
    }

    private string get_current_line (Gtk.TextIter? start=null) {
        var current_buffer = current_source.buffer;
        Gtk.TextIter end;

        if (start == null) {
            current_buffer.get_iter_at_offset (out start, current_buffer.cursor_position);
        }

        start.backward_chars (start.get_line_offset ());
        end = start;
        end.forward_to_line_end ();

        return current_buffer.get_text (start, end, false);
    }

    private bool parse_ordered_list_item (string line, ref int current_number, out string item_text) {
        item_text = "";
        int first_point_character = line.index_of_char ('.');
        if (first_point_character < 0) {
            return false;
        }

        item_text = line.substring (first_point_character + 1).strip ();

        var line_start = line.substring (0, first_point_character);
        if (!int.try_parse (line_start, out current_number)) {
            return false;
        }
        return true;
    }

    private bool parse_unordered_list_item (string line, out char ul_marker) {
        if ((line[0] == '*' || line[0] == '-') && line[1] == ' ') {
            ul_marker = line[0];
            return true;
        }
        ul_marker = '\0';
        return false;
    }

    private void insert_link () {
        var current_buffer = current_source.buffer;
        current_buffer.begin_user_action ();
        if (current_buffer.has_selection) {
            insert_around_selection ("[", "]");
            current_buffer.insert_at_cursor ("()", 2);
            go_back_n_chars (1);
        } else {
            current_buffer.insert_at_cursor ("[]", 2);
            current_buffer.insert_at_cursor ("()", 2);
            go_back_n_chars (3);
        }
        current_buffer.end_user_action ();
    }

    private void go_back_n_chars (int back_chars) {
        Gtk.TextIter insert_position;
        var current_buffer = current_source.buffer;
        current_buffer.get_iter_at_offset (out insert_position, current_buffer.cursor_position - back_chars);
        current_buffer.place_cursor (insert_position);
    }

    private void insert_around_selection (string before, string after) {
        Gtk.TextIter start, end;
        var current_buffer = current_source.buffer;
        current_buffer.get_selection_bounds (out start, out end);
        var mark_end = new Gtk.TextMark (null);
        current_buffer.add_mark (mark_end, end);
        current_buffer.place_cursor (start);
        current_buffer.insert_at_cursor (before, before.length);

        current_buffer.get_iter_at_mark (out end, mark_end);
        current_buffer.place_cursor (end);
        current_buffer.insert_at_cursor (after, after.length);
    }

    public void add_markdown_tag (string tag) {
        var current_buffer = current_source.buffer;
        current_buffer.begin_user_action ();
        if (current_buffer.has_selection) {
            insert_around_selection (tag, tag);
        } else {
            current_buffer.insert_at_cursor (tag, tag.length);
            current_buffer.insert_at_cursor (tag, tag.length);
        }
        current_buffer.end_user_action ();
        go_back_n_chars (tag.length);
    }

    public void deactivate () {
        if (current_source != null) {
            current_source.key_press_event.disconnect (shortcut_handler);
            current_source.notify["language"].disconnect (configure_shortcuts);
        }
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Code.Plugins.MarkdownActions));
}
