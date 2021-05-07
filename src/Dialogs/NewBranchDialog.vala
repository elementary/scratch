/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public class Scratch.Dialogs.NewBranchDialog : Granite.MessageDialog {
    public FolderManager.ProjectFolderItem active_project { get; construct; }
    // public unowned List<FolderManager.ProjectFolderItem> project_list { get; construct; }

    private Granite.ValidatedEntry new_branch_name_entry;
    public string new_branch_name {
        get {
            return new_branch_name_entry.text;
        }
    }

    public NewBranchDialog (FolderManager.ProjectFolderItem project) {
        Object (
            transient_for: ((Gtk.Application)(GLib.Application.get_default ())).get_active_window (),
            active_project: project,
            image_icon: new ThemedIcon ("git")
        );
    }

    construct {
        assert (active_project.is_git_repo);
        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        primary_text = _("Create a new branch of “%s/%s”").printf (
            active_project.file.file.get_basename (),
            active_project.get_current_branch_name ()
        );
        ///TRANSLATORS "Git" is a proper name and must not be translated
        secondary_text = _("The branch name must comply with Git rules and must not already exist.");
        badge_icon = new ThemedIcon ("list-add");

        new_branch_name_entry = new Granite.ValidatedEntry () {
            activates_default = true
        };

        custom_bin.add (new_branch_name_entry);

        var create_button = (Gtk.Button) add_button (_("Create Branch"), Gtk.ResponseType.APPLY);
        create_button.can_default = true;
        create_button.has_default = true;
        create_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        new_branch_name_entry.bind_property (
            "is-valid", create_button, "sensitive", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
        );

        new_branch_name_entry.changed.connect (() => {
            unowned var new_name = new_branch_name_entry.text;
            if (!active_project.is_valid_new_branch_name (new_name)) {
                new_branch_name_entry.is_valid = false;
                return;
            }

            if (active_project.has_local_branch_name (new_name)) {
                new_branch_name_entry.is_valid = false;
                return;
            }

            //Do we need to check remote branches as well?
            new_branch_name_entry.is_valid = true;
        });
    }
}
