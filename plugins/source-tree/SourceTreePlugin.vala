/***
  BEGIN LICENSE

  Copyright (C) 2013 Tom Beckmann <tomjonabc@gmail.com>
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

public const string NAME = _("Source Tree");
public const string DESCRIPTION = _("Have a look at your sources organized in a nice tree");

const bool HIDE_TOOLBAR = true;

Scratch.Services.Interface scratch_interface;

public class Folder : Granite.Widgets.SourceList.ExpandableItem {
    public File file { get; construct set; }
    bool loaded = false;

    const string ATTRIBUTES = FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE +
        "," + FileAttribute.STANDARD_ICON;
    const string[] IGNORED = { "pyc", "class", "pyo", "o" };


    public Folder (File dir) {
        file = dir;
        name = dir.get_basename ();
        selectable = false;

        //need to add one item to make the folder appear
        add (new Granite.Widgets.SourceList.Item (_("Loading...")));

        toggled.connect (() => {
            if (!expanded || loaded)
                return;

            loaded = true;

            load ();
            var children_tmp = new Gee.ArrayList<Granite.Widgets.SourceList.Item> ();
            children_tmp.add_all (children);
            foreach (var child in children_tmp) {
                if (!(child is Document) && !(child is Folder))
                    remove (child);
            }
        });
    }

    public void load () {
        try {
            var enumerator = file.enumerate_children (ATTRIBUTES, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
            FileInfo? file_info = null;

            while ((file_info = enumerator.next_file ()) != null) {
                var file_name = file_info.get_name ();
                var file_type = file_info.get_file_type ();

                if (file_type == FileType.REGULAR && !file_name.has_suffix ("~") && !file_name.has_prefix (".")) {
                    // Ignore some kind of temporany files

                    bool ignore = false;
                    for (int n = 0; n < IGNORED.length; n++) {
                        string ignored_suffix = IGNORED[n];
                        debug (ignored_suffix);
                        var tmp = file_name.split (".");
                        string suffix = tmp[tmp.length-1];
                        if (suffix == ignored_suffix)
                            ignore = true;
                    }
                    if (!ignore)
                        add (new Document (file.get_child (file_name), file_info.get_icon ()));

                } else if (file_type == FileType.DIRECTORY && !file_name.has_prefix (".")) {
                    add (new Folder (file.get_child (file_name)));
                }
            }
        } catch (Error e) { warning (e.message); }
    }
}

public class Document : Granite.Widgets.SourceList.Item
{
    public Scratch.Services.Document? doc { get; private set; }
    public File file { get; construct set; }

    public Document (File file, Icon icon)
    {
        Object (file: file, icon: icon);

        name = file.get_basename ();

        action_activated.connect (() => {
            if (parent == null)
                return;

            scratch_interface.close_document (doc);
            parent.remove (this);
        });
    }

    public Document.scratch (Scratch.Services.Document _doc)
    {
        Icon icon = new FileIcon (_doc.file);
        try {
            icon = _doc.file.query_info (FileAttribute.STANDARD_ICON, 0).get_icon ();
        } catch (Error e) { warning (e.message); }
        this (_doc.file, icon);
        doc = _doc;
        try {
            activatable = Gtk.IconTheme.get_default ().lookup_by_gicon (new ThemedIcon ("window-close-symbolic"), 16, 0).load_symbolic ({1, 1, 1, 1});
        } catch (Error e) { warning (e.message); }
    }
}

public class Bookmark : Granite.Widgets.SourceList.Item
{
    public Scratch.Services.Document doc { get; construct set; }
    public Gtk.TextIter iter { get; construct set; }

    public Bookmark (Scratch.Services.Document doc, Gtk.TextIter iter)
    {
        Object(name: doc.get_basename () + ":" + (iter.get_line () + 1).to_string (),
            doc: doc, iter: iter, icon: new ThemedIcon ("tag-new"));
        try {
            activatable = Gtk.IconTheme.get_default ().lookup_by_gicon (new ThemedIcon ("window-close-symbolic"), 16, 0).load_symbolic ({1, 1, 1, 1});
        } catch (Error e) { warning (e.message); }

        action_activated.connect (() => {
            if (parent == null)
                return;

            parent.remove (this);
        });
    }
}

namespace Scratch.Plugins {
    public class SourceTreePlugin : Peas.ExtensionBase, Peas.Activatable {
        Scratch.Services.Interface plugins;
        public Object object { owned get; construct; }

        Gtk.ToolButton? new_button = null;
        Gtk.ToolButton? bookmark_tool_button = null;
        Gtk.Notebook scratch_notebook;
        Gtk.Notebook side_notebook;
        Granite.Widgets.SourceList view;
        Granite.Widgets.SourceList.ExpandableItem category_files;
        Granite.Widgets.SourceList.ExpandableItem category_project;
        Granite.Widgets.SourceList.ExpandableItem category_bookmarks;

        File? root = null;

        bool my_select = false;

        bool _in_side_notebook;
        bool in_side_notebook {
            get {
                return _in_side_notebook;
            }

            set {
                _in_side_notebook = value;
                this.bookmark_tool_button.visible = value;
                this.bookmark_tool_button.no_show_all = value;
            }
        }

        public void activate () {
            plugins = (Scratch.Services.Interface) object;
            plugins.hook_notebook_sidebar.connect (on_hook_sidebar);
            plugins.hook_document.connect (on_hook_document);
            plugins.hook_toolbar.connect ((toolbar) => {
                MainWindow window = plugins.manager.window;
                if (this.bookmark_tool_button != null && this.new_button != null)
                    return;
                this.new_button = window.main_actions.get_action ("NewTab").create_tool_item() as Gtk.ToolButton;
                this.bookmark_tool_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("bookmark-new", Gtk.IconSize.LARGE_TOOLBAR), _("Bookmark"));
                bookmark_tool_button.show_all ();
                bookmark_tool_button.clicked.connect (() => add_bookmark ());
                toolbar.pack_start (bookmark_tool_button);
                toolbar.pack_start (new_button);
                //toolbar.insert (bookmark_tool_button, toolbar.get_item_index (toolbar.find_button) + 1);
                //toolbar.insert (new_button, 0);
                in_side_notebook = false;
            });
            plugins.hook_split_view.connect ((view) => {
                this.bookmark_tool_button.visible = ! view.is_empty ();
                this.bookmark_tool_button.no_show_all = view.is_empty ();
                view.welcome_shown.connect (() => {
                    int current_page = this.side_notebook.get_current_page ();
                    if (this.side_notebook.get_nth_page (current_page) == this.view) {
                        this.side_notebook.remove_page (current_page);
                        in_side_notebook = false;
                    }
                });
            });

            scratch_interface = ((Scratch.Services.Interface)object);
        }

        public void deactivate () {
            if (view != null)
                view.destroy();
            if (bookmark_tool_button != null)
                bookmark_tool_button.destroy ();
            if (new_button != null)
                new_button.destroy ();
            scratch_notebook.set_show_tabs (HIDE_TOOLBAR);
        }

        public void update_state () {
        }

        void on_hook_sidebar (Gtk.Notebook notebook) {
            if (view != null)
                return;

            side_notebook = notebook;
            view = new Granite.Widgets.SourceList ();

            view.get_style_context ().add_class ("sidebar");
            category_files = new SourceTreePluginExpandableItem (_("Files"));
            category_project = new SourceTreePluginExpandableItem (_("Project"));
            category_bookmarks = new SourceTreePluginExpandableItem (_("Bookmarks"));
            view.root.add (category_files);
            view.root.add (category_project);
            view.root.add (category_bookmarks);
            view.show_all ();

            view.item_selected.connect ((new_current) => {
                if (my_select) return;

                if (new_current is Bookmark) {
                    var bookmark = new_current as Bookmark;
                    ((Scratch.Services.Interface)object).open_file (bookmark.doc.file);
                    var text = bookmark.doc.source_view;
                    text.buffer.place_cursor (bookmark.iter);
                    text.scroll_to_iter (bookmark.iter, 0.0, true, 0.5, 0.5);
                    return;
                }

                var doc = new_current as Document;
                ((Scratch.Services.Interface)object).open_file (doc.file);
            });
        }

        void on_hook_document (Scratch.Services.Document doc) {
            scratch_notebook = (doc.get_parent () as Gtk.Notebook);
            scratch_notebook.set_show_tabs (!HIDE_TOOLBAR);

            foreach (var d in category_files.children) {
                if ((d as Document).file == doc.file) {
                    view.selected = d;
                    return;
                }
            }

            if (doc.file == null) {
                doc.doc_saved.connect (wait_for_save);
                return;
            }

            add_doc (doc);

            ensure_in_notebook ();
        }

        void ensure_in_notebook () {
            if (!in_side_notebook) {
                side_notebook.append_page (this.view, new Gtk.Label (_("Source Tree")));
                in_side_notebook = true;
            }
        }

        void wait_for_save (Scratch.Services.Document doc) {
            doc.doc_saved.disconnect (wait_for_save);
            add_doc (doc);
        }

        void add_doc (Scratch.Services.Document doc) {
            var item = new Document.scratch (doc);
            category_files.add (item);
            my_select = true;
            view.selected = item;
            my_select = false;

            var new_root = detect_project (doc.file);
            if (root == null || root.get_path () != new_root.get_path ()) {
                root = new_root;
                category_project.clear ();
                category_project.expand_all ();
                category_project.add (new Folder (root));
            }
        }

        void add_bookmark () {
            var doc = (view.selected as Document).doc as Scratch.Services.Document;
            var buffer = doc.source_view.buffer;
            Gtk.TextIter iter;
            buffer.get_iter_at_offset (out iter, buffer.cursor_position);

            var bookmark = new Bookmark (doc, iter);
            category_bookmarks.add (bookmark);
            category_bookmarks.expand_all ();
        }

        const string [] vcss = {".bzr", ".git", ".hg"};
        File? detect_project (File opened)  {
            //go up looking for a vcs indicating folder
            var dir = opened;
            while ((dir = dir.get_parent ()) != null) {
                foreach (var vcs in vcss) {
                    if (dir.get_child (vcs).query_exists ()) {
                        return dir;
                    }
                }
            }

            //checking for src, might not be under version control yet
            dir = opened.get_parent ();
            if (dir.get_basename () == "src") {
                dir = dir.get_parent ();
            } else if (dir.get_parent ().get_basename () == "src") {
                dir = dir.get_parent ().get_parent ();
            }

            return dir;
        }
    }

    internal class SourceTreePluginExpandableItem : Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable {

        public SourceTreePluginExpandableItem (string name) {
            base (name);
        }

        public int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
            if (a.get_type () ==  b.get_type ()) {
                return a.name.collate (b.name);
            } else if (a is Folder ) {
                return -1;
            } else if (b is Folder ) {
                return 1;
            } else if (a is Document ) {
                return -1;
            } else if (b is Document ) {
                return 1;
            } else if (a is Bookmark ) {
                return -1;
            } else if (b is Bookmark ) {
                return 1;
            } else {
                return 0;
            }
        }

        public bool allow_dnd_sorting () {
            return false;
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
  var objmodule = module as Peas.ObjectModule;
  objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Scratch.Plugins.SourceTreePlugin));
}
