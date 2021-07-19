/*-
 * Copyright (c) 2017-2018 elementary LLC. (https://elementary.io)
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
 */

public class Code.Plugins.CtagsSymbolOutline : Object, Code.Plugins.SymbolOutline {
    public const string OUTLINE_RESOURCE_URI = "resource:///io/elementary/code/plugin/outline/";
    public Scratch.Services.Document doc { get; protected set; }
    Granite.Widgets.SourceList store;
    Granite.Widgets.SourceList.ExpandableItem root;
    GLib.Subprocess current_subprocess;

    public CtagsSymbolOutline (Scratch.Services.Document _doc) {
        doc = _doc;
        doc.doc_saved.connect (() => {parse_symbols ();});

        root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));

        store = new Granite.Widgets.SourceList ();
        store.root.add (root);
        store.item_selected.connect ((selected) => {
            if (selected == null) {
                return;
            }

            goto (doc, ((CtagsSymbol)selected).line);
            store.selected = null;
        });
    }

    public void parse_symbols () {
        if (current_subprocess != null)
            current_subprocess.force_exit ();

        try {
            current_subprocess = new GLib.Subprocess (
                GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_SILENCE,
                "ctags", "-f", "-", "--format=2", "--excmd=n", "--fields=nstK", "--extra=", "--sort=no", doc.file.get_path ()
            );

            parse_output.begin (current_subprocess);
        } catch (GLib.Error e) {
            critical (e.message);
        }
    }

    private async void parse_output (GLib.Subprocess subprocess) {
        var parent_dependent = new Gee.LinkedList<CtagsSymbolIter> ();
        var new_root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));

        var datainput = new GLib.DataInputStream (subprocess.get_stdout_pipe ());
        try {
            string symbol;
            while ((symbol = yield datainput.read_line_async ()) != null) {
                if (symbol == "")
                    continue;

                var parts = symbol.split ("\t");
                if (parts.length < 5) {
                    continue;
                }

                var name = parts[0];
                // 1 => filename
                // 2 => line number with weird trailing chars
                var type = parts[3];
                int line = int.parse (parts[4].offset ("line:".length));
                string? parent = null;
                GLib.Icon? parent_icon = null;
                if (parts.length > 5 && parts[5] != null) {
                    if ("typeref:" in parts[5]) {
                        parent = parts[5].offset ("typeref:".length);
                    } else if ("class:" in parts[5]) {
                        parent = parts[5].offset ("class:".length);
                        parent_icon = new ThemedIcon ("lang-class");
                    } else if ("struct:" in parts[5]) {
                        parent = parts[5].offset ("struct:".length);
                        parent_icon = new ThemedIcon ("lang-struct");
                    } else if ("enum:" in parts[5]) {
                        parent = parts[5].offset ("enum:".length);
                        parent_icon = new ThemedIcon ("lang-enum");
                    }
                }

                Icon? icon = null;
                switch (type) {
                    case "class":
                        icon = new ThemedIcon ("lang-class");
                        break;
                    case "struct":
                        icon = new ThemedIcon ("lang-struct");
                        break;
                    case "field":
                    case "member":
                    case "variable":
                        icon = new ThemedIcon ("lang-property");
                        break;
                    case "enum":
                    case "enumerator":
                        icon = new ThemedIcon ("lang-enum");
                        break;
                    case "macro":
                    case "constant":
                    case "typedef":
                        icon = new ThemedIcon ("lang-constant");
                        break;
                    case "constructor":
                        icon = new ThemedIcon ("lang-constructor");
                        break;
                    case "destructor":
                    case "method":
                    case "function":
                        icon = new ThemedIcon ("lang-method");
                        break;
                    case "namespace":
                        icon = new ThemedIcon ("lang-namespace");
                        break;
                    case "package":
                        break;
                    case "property":
                        icon = new ThemedIcon ("lang-property");
                        break;
                }

                if (parent == null) {
                    var s = new CtagsSymbol (doc, name, line, icon);
                    new_root.add (s);
                } else {
                    parent_dependent.add (new CtagsSymbolIter (name, parent, line, parent_icon));
                }
            }
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var found_something = true;
        while (found_something && parent_dependent.size > 0) {
            found_something = false;
            var iter = parent_dependent.iterator ();
            while (iter.has_next ()) {
                iter.next ();
                var i = iter.get ();

                var parent = find_existing (i.parent, new_root);
                if (parent != null) {
                    found_something = true;
                    parent.add (new CtagsSymbol (doc, i.name, i.line, i.icon));
                    iter.remove ();
                } else {
                    if (":" in i.parent) {
                        var parent_parts = i.parent.split (":", 2);
                        parent = find_existing (parent_parts[1], new_root);
                        if (parent != null) {
                            parent.name = i.name;
                            switch (parent_parts[0]) {
                                case "class":
                                    parent.icon = new ThemedIcon ("lang-class");
                                    break;
                                case "struct":
                                    parent.icon = new ThemedIcon ("lang-struct");
                                    break;
                                case "enum":
                                    parent.icon = new ThemedIcon ("lang-enum");
                                    break;
                            }
                            iter.remove ();
                            continue;
                        }
                    }
                    // anonymous enum
                    if (i.parent.has_prefix ("__anon")) {
                        var e = new CtagsSymbol (doc, i.parent, i.line - 1, new ThemedIcon ("lang-enum"));
                        new_root.add (e);

                        e.add (new CtagsSymbol (doc, i.name, i.line, i.icon));
                        iter.remove ();
                    }
                }
            }
        }

        // just add the rest
        foreach (var symbol in parent_dependent) {
            new_root.add (new CtagsSymbol (doc, symbol.name, symbol.line, symbol.icon));
        }

        Idle.add (() => {
            double adjustment_value = store.vadjustment.value;
            store.root.clear ();
            store.root.add (new_root);
            store.root.expand_all ();
            store.vadjustment.set_value (adjustment_value);

            destroy_root (root);
            root = new_root;

            return false;
        });
    }

    private void destroy_root (Granite.Widgets.SourceList.ExpandableItem to_destroy) {
        var children = iterate_children (to_destroy);
        to_destroy.clear ();
        foreach (var item in children) {
            item.clear ();
            var parent = item.parent;
            if (parent != null) {
                parent.remove (item);
            }
        }
    }

    private Gee.TreeSet<CtagsSymbol> iterate_children (Granite.Widgets.SourceList.ExpandableItem parent) {
        var result = new Gee.TreeSet<CtagsSymbol> ();
        foreach (var child in parent.children) {
            result.add_all (iterate_children ((CtagsSymbol)child));
        }
        return result;
    }

    CtagsSymbol? find_existing (string name, Granite.Widgets.SourceList.ExpandableItem parent) {
        CtagsSymbol match = null;
        foreach (var child in parent.children) {
            var child_symbol = child as CtagsSymbol;
            if (child_symbol.name == name) {
                match = child_symbol;
                break;
            } else {
                var res = find_existing (name, child_symbol);
                if (res != null)
                    return res;
            }
        }

        return match;
    }

    public Granite.Widgets.SourceList get_source_list () {
        return store;
    }
}
