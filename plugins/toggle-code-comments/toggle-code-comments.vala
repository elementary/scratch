/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public const string NAME = _("Toggle Code Comments");
public const string DESCRIPTION = _("Add/remove comments with Ctrl+M");

public class Scratch.Plugins.ToggleCodeComments: Peas.ExtensionBase, Peas.Activatable {

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }
    Scratch.MainWindow main_window;
    public void update_state () { return; }

    private enum CommentType {
        NONE,
        LINE,
        BLOCK
    }

    /*
     * Activate plugin.
     */
    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_window.connect ((w) => {
            main_window = w;

            var comment_action = new SimpleAction ("toggle-comment", null);
            comment_action.activate.connect (on_toggle_comment);
            main_window.actions.add_action (comment_action);

            var app = main_window.app;
            app.add_accelerator ("<Primary>m", "win.toggle-comment", null);
        });
    }

    /*
     * Deactivate plugin.
     */
    public void deactivate () {
        var app = main_window.app;
        app.remove_accelerator ("win.toggle-comment", null);

        main_window.actions.remove_action ("toggle-comment");
    }

    private Gtk.SourceBuffer? get_buffer () {
        if (main_window.get_current_document () != null) {
            var text_view = main_window.get_current_document ().source_view;
            return (Gtk.SourceBuffer) text_view.buffer;
        }

        return null;
    }

    private static CommentType get_comment_tags_for_lang (Gtk.SourceLanguage lang,
                                                          CommentType type,
                                                          out string? start,
                                                          out string? end) {
        start = null;
        end = null;

        if (type == CommentType.BLOCK) {
            start = lang.get_metadata ("block-comment-start");
            end = lang.get_metadata ("block-comment-end");

            if (start != null && end != null) {
                return CommentType.BLOCK;
            } else {
                start = lang.get_metadata ("line-comment-start");
                if (start != null) {
                    return CommentType.LINE;
                } else {
                    return CommentType.NONE;
                }
            }
        } else if (type == CommentType.LINE) {
            start = lang.get_metadata ("line-comment-start");
            if (start != null) {
                return CommentType.LINE;
            } else {
                start = lang.get_metadata ("block-comment-start");
                end = lang.get_metadata ("block-comment-end");

                if (start != null && end != null) {
                    return CommentType.BLOCK;
                } else {
                    return CommentType.NONE;
                }
            }
        }

        return CommentType.NONE;
    }

    // Returns whether or not all lines within a region are already commented.
    // This is to detect whether to toggle comments on or off. If all lines are commented, then we want to remove
    // those comments. If only some are commented, then the user likely selected a chunk of code that already contained
    // a couple of comments. In that case, we still want to insert comments.
    private static CommentType lines_already_commented (Gtk.SourceBuffer buffer,
                                                        Gtk.TextIter start,
                                                        Gtk.TextIter end,
                                                        uint num_lines,
                                                        Gtk.SourceLanguage lang) {

        string start_tag, end_tag;
        var type = get_comment_tags_for_lang (lang, CommentType.BLOCK, out start_tag, out end_tag);
        var selection = buffer.get_slice (start, end, true);
        if (type == CommentType.BLOCK) {
            var regex_string = """^\s*(?:%s)+[\s\S]*(?:%s)+$""";
            regex_string = regex_string.printf (Regex.escape_string (start_tag), Regex.escape_string (end_tag));
            if (Regex.match_simple (regex_string, selection)) {
                return CommentType.BLOCK;
            }
        }

        type = get_comment_tags_for_lang (lang, CommentType.LINE, out start_tag, out end_tag);
        if (type == CommentType.LINE) {
            var regex_string = """^\s*(?:%s)+.*$""";
            regex_string = regex_string.printf (Regex.escape_string (start_tag));

            string[] lines = Regex.split_simple ("""[\r\n]""", selection);
            if (lines.length != num_lines) {
                warning ("Line number mismatch when trying to detect comments");
                return CommentType.NONE;
            }

            foreach (var line in lines) {
                var empty_line = line.chomp ().chug () == "";
                if (!Regex.match_simple (regex_string, line) && !empty_line) {
                    return CommentType.NONE;
                }
            }

            return CommentType.LINE;
        }

        return CommentType.NONE;
    }

    private static void remove_comments (Gtk.SourceBuffer buffer,
                                         Gtk.TextIter start,
                                         Gtk.TextIter end,
                                         uint num_lines,
                                         CommentType type,
                                         string? start_tag,
                                         string? end_tag) {

        buffer.begin_user_action ();

        if (type == CommentType.BLOCK) {
            var emark = buffer.create_mark ("end", end, false);

            var iter = start;
            var head_iter = start;
            head_iter.forward_chars (start_tag.length);

            while (!iter.ends_line ()) {
                var text = buffer.get_slice (iter, head_iter, true);
                if (text == start_tag) {
                    buffer.delete (ref iter, ref head_iter);
                    break;
                }

                iter.forward_char ();
                head_iter.forward_char ();
            }

            buffer.get_iter_at_mark (out iter, emark);
            head_iter = iter;
            head_iter.backward_chars (end_tag.length);

            while (!iter.starts_line ()) {
                var text = buffer.get_slice (head_iter, iter, true);
                if (text == end_tag) {
                    buffer.delete (ref head_iter, ref iter);
                    break;
                }

                iter.backward_char ();
                head_iter.backward_char ();
            }

            buffer.delete_mark (emark);
        } else if (type == CommentType.LINE) {
            var imark = buffer.create_mark ("iter", start, false);
            var lines_processed = 0;
            var iter = start;
            var head_iter = start;

            while (lines_processed < num_lines) {
                buffer.get_iter_at_mark (out iter, imark);
                buffer.get_iter_at_mark (out head_iter, imark);
                head_iter.forward_chars (start_tag.length);

                var text = "";
                while (!iter.ends_line ()) {
                    text = buffer.get_slice (iter, head_iter, true);
                    if (text == start_tag) {
                        buffer.delete (ref head_iter, ref iter);
                        break;
                    }

                    iter.forward_char ();
                    head_iter.forward_char ();
                }

                buffer.get_iter_at_mark (out iter, imark);
                iter.forward_line ();
                lines_processed++;
                imark = buffer.create_mark ("iter", iter, false);
            }
        }

        buffer.end_user_action ();
    }

    private static void add_comments (Gtk.SourceBuffer buffer,
                                      Gtk.TextIter start,
                                      Gtk.TextIter end,
                                      uint num_lines,
                                      CommentType type,
                                      string? start_tag,
                                      string? end_tag) {
        buffer.begin_user_action ();

        var smark = buffer.create_mark ("start", start, false);
        var imark = buffer.create_mark ("iter", start, false);
        var emark = buffer.create_mark ("end", end, false);

        Gtk.TextIter iter;

        if (type == CommentType.BLOCK) {
            buffer.insert (ref start, start_tag, -1);

            buffer.get_iter_at_mark (out iter, emark);
            buffer.insert (ref iter, end_tag, -1);
        } else if (type == CommentType.LINE) {
            buffer.get_iter_at_mark (out iter, imark);

            for (int i = 0; i < num_lines; i++) {
                if (!iter.ends_line ()) {
                    buffer.insert (ref iter, start_tag, -1);
                }

                buffer.get_iter_at_mark (out iter, imark);
                iter.forward_line ();
                buffer.delete_mark (imark);
                imark = buffer.create_mark ("iter", iter, false);
            }
        }

        buffer.end_user_action ();
        buffer.delete_mark (imark);

        Gtk.TextIter new_start, new_end;

        buffer.get_iter_at_mark (out new_start, smark);
        buffer.get_iter_at_mark (out new_end, emark);

        if (!new_start.starts_line ()) {
            new_start.set_line_offset (0);
        }

        buffer.select_range (new_start, new_end);
        buffer.delete_mark (smark);
        buffer.delete_mark (emark);
    }

    private void on_toggle_comment () {
        var buffer = get_buffer ();
        if (buffer != null) {
            Gtk.TextIter start, end;
            var sel = buffer.get_selection_bounds (out start, out end);
            var num_lines = 0;

            // There wasn't a selection, use the line the cursor is on
            if (!sel) {
                buffer.get_iter_at_mark (out start, buffer.get_insert ());
                start.set_line_offset (0);
                end.assign (start);
                end.forward_to_line_end ();
                num_lines = 1;
            } else {
                // Move the start and end of the selection to the appropriate start/end of lines
                if (start.ends_line ()) {
                    start.forward_line ();
                } else if (!start.starts_line ()) {
                    start.set_line_offset (0);
                }

                if (end.starts_line ()) {
                    end.backward_char ();
                } else if (!end.ends_line ()) {
                    end.forward_to_line_end ();
                }

                num_lines = end.get_line () - start.get_line () + 1;
            }

            string? start_tag, end_tag;
            var lang = buffer.get_language ();
            var lines_commented = lines_already_commented (buffer, start, end, num_lines, lang);

            if (lines_commented != CommentType.NONE) {
                var existing_comment_tags = get_comment_tags_for_lang (lang, lines_commented, out start_tag, out end_tag);
                if (lines_commented == existing_comment_tags) {
                    remove_comments (buffer, start, end, num_lines, lines_commented, start_tag, end_tag);
                }
            } else {
                var type = get_comment_tags_for_lang (lang, CommentType.LINE, out start_tag, out end_tag);
                if (type != CommentType.NONE) {
                    add_comments (buffer, start, end, num_lines, type, start_tag, end_tag);
                }
            }
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Peas.Activatable),
                                      typeof(Scratch.Plugins.ToggleCodeComments));
}
