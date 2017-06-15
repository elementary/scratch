// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Julien Spautz <spautz.julien@gmail.com>
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

namespace Scratch.Plugins.FolderManager {
    /**
     * Expandable item in the source list, represents a folder.
     * Monitored for changes inside the directory.
     */
    internal class FolderItem : Item {
        private GLib.FileMonitor monitor;
        private bool children_loaded = false;

        public FolderItem (File file, FileView view) requires (file.is_valid_directory) {
            Object (file: file, view: view);        
        }
        
        construct {
            if (file.children.length () > 0) {
                add (new Granite.Widgets.SourceList.Item ("")); // dummy
            }
            
            toggled.connect (() => {
                if (expanded && n_children <= 1) {
                    clear ();
                    add_children ();
                    children_loaded = true;
                }
            });
            
            try {
                monitor = file.file.monitor_directory (GLib.FileMonitorFlags.NONE);
                monitor.changed.connect (on_changed);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        }
        
        public override Gtk.Menu? get_context_menu () {
            var menu = new Gtk.Menu ();
            
            if (parent == view.root) {
                var item = new Gtk.MenuItem.with_label (_("Close Folder"));
                item.activate.connect (do_close);
                menu.append (item);
            } else {
                var item = new Gtk.MenuItem.with_label (_("Open"));
                item.activate.connect (() => { view.open_folder (file); });
                menu.append (item);
            }
            
            var rename_item = new Gtk.MenuItem.with_label (_("Rename"));
            rename_item.activate.connect (() => view.start_editing_item (this));
            menu.append (rename_item);

            var new_file_item = new Gtk.MenuItem.with_label (_("Add File"));
            /*new_file_item.activate.connect (() => add_file ());*/
            menu.append (new_file_item);

            var new_folder_item = new Gtk.MenuItem.with_label (_("Add Folder"));
            /*new_folder_item.activate.connect(() => add_folder ());*/
            menu.append (new_folder_item);

            var delete_item = new Gtk.MenuItem.with_label (_("Move to Trash"));
            delete_item.activate.connect (() => trash ());
            menu.append (delete_item);
            
            menu.show_all ();
            return menu;
        }
        
        private void add_children () {
            foreach (var child in file.children) {
                if (child.is_valid_directory) {
                    var item = new FolderItem (child, view);
                    add (item);
                } else if (child.is_valid_textfile) {
                    var item = new FileItem (child, view);
                    add (item);
                }
            }
        }
        
        private void do_close () {
            /*view.close_folder (path);*/
        }

        private new void trash () {
            if (parent == view.root) {
                do_close ();
            }

            base.trash ();
        }

        private void on_changed (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {

            if (!children_loaded) {
                this.file.reset_cache ();
                return;
            }

            switch (event) {
                case GLib.FileMonitorEvent.DELETED:
                    var children_tmp = new Gee.ArrayList<Granite.Widgets.SourceList.Item> ();
                    children_tmp.add_all (children);
                    foreach (var item in children_tmp) {
                        if ((item as Item).path == source.get_path ()) {
                            remove (item);
                        }
                    }

                    break;
                case GLib.FileMonitorEvent.CREATED:
                    if (source.query_exists () == false) {
                        return;
                    }

                    var file = new File (source.get_path ());
                    var exists = false;
                    foreach (var item in children) {
                        if ((item as Item).path == file.path) {
                            exists = true;
                            break;
                        }
                    }

                    if (!exists) {
                        if (file.is_valid_textfile) {
                            this.add (new FileItem (file, view));
                        } else if (file.is_valid_directory) {
                            this.add (new FolderItem (file, view));
                        }
                    }

                    break;
            }
        }
    }
}