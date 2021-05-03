namespace Scratch.Widgets {
    public class SourceGutterRenderer : Gtk.SourceGutterRenderer {
        private Gee.HashMap<int, Services.VCStatus> line_status_map;
        public FolderManager.ProjectFolderItem? project { get; set; default = null; }
        public string workdir_path {
            get {
                return project != null ? project.top_level_path : "";
            }
        }

        private string _doc_path = "";
        public string doc_path {
            get {
                return _doc_path;
            }

            set {
                _doc_path = value;
                refresh ();
            }
        }

        public bool project_set {
            get {
                return project != null;
            }
        }

        public SourceGutterRenderer () {
            line_status_map = new Gee.HashMap<int, Services.VCStatus> ();
            set_size (3);
            set_visible (true);
        }

        public override void draw (Cairo.Context cr,
                                   Gdk.Rectangle bg,
                                   Gdk.Rectangle area,
                                   Gtk.TextIter start,
                                   Gtk.TextIter end,
                                   Gtk.SourceGutterRendererState state) {

            base.draw (cr, bg, area, start, end, state);
            var gutter_line_no = start.get_line () + 2; // For some reason, all the diffs are off by two lines...?
            if (line_status_map.has_key (gutter_line_no)) {
                set_background (line_status_map.get (gutter_line_no).to_rgba ());
            } else {
                set_background (Services.VCStatus.NONE.to_rgba ());
            }
        }

        public void refresh () {
            project.refresh_diff (ref line_status_map, _doc_path); 
        }
    }
}
