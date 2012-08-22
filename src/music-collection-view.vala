/*
 * Copyright (C) 2012 Cesar Garcia Tapia <tapia@openshine.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Gee;

internal enum Music.CollectionType {
    ARTISTS = 0,
    ALBUMS,
    SONGS,
    PLAYLISTS
}

private class Music.CollectionView {
    public Gtk.Widget actor { get { return scrolled_window; } }

    public signal void item_selected (string item_id, Music.ItemType? item_type, Grl.Media? media);

    private Music.MusicListStore model;

    private Gtk.ScrolledWindow scrolled_window;
    private Gd.MainIconView icon_view;

    private string button_press_item_path;

    private enum ModelColumns {
        SCREENSHOT = Gd.MainColumns.ICON,
        TITLE = Gd.MainColumns.PRIMARY_TEXT,
        INFO = Gd.MainColumns.SECONDARY_TEXT,
        SELECTED = Gd.MainColumns.SELECTED,
        ITEM = Gd.MainColumns.LAST,

        LAST
    }

    public CollectionView () {
        App.app.app_state_changed.connect (on_app_state_changed);
        App.app.browse_back.connect (on_browse_back);

        model = new Music.MusicListStore (); 
        setup_view ();
        model.connect_signals();
    }

    private void setup_view () {
        icon_view = new Gd.MainIconView ();
        icon_view.set_model (model);
        icon_view.get_style_context ().add_class ("music-bg");
        //icon_view.activate_on_single_click (true);
        icon_view.set_selection_mode (false);
        icon_view.button_press_event.connect (on_button_press_event);
        icon_view.button_release_event.connect (on_button_release_event);

        scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_window.add (icon_view);

        icon_view.show ();
        scrolled_window.show ();
    }

    private bool on_button_press_event (Gtk.Widget view, Gdk.EventButton event) {
        Gtk.TreePath path = icon_view.get_path_at_pos ((int) event.x, (int) event.y);
        if (path != null)
            button_press_item_path = path.to_string ();

        if (!App.app.selection_mode || path == null)
            return false;

        return false;
        /*
        CollectionItem item = get_item_for_path (path);
        bool found = item != null;

        /* if we did not find the item in the selection, block
         * drag and drop, while in selection mode
        return !found;
         */
    }

    private bool on_button_release_event (Gtk.Widget view, Gdk.EventButton event) {
        /* eat double/triple click events */
        if (event.type != Gdk.EventType.BUTTON_RELEASE)
            return true;

        Gtk.TreePath path = icon_view.get_path_at_pos ((int) event.x, (int) event.y);

        var same_item = false;
        if (path != null) {
            string button_release_item_path = path.to_string ();

            same_item = button_press_item_path == button_release_item_path;
        }

        button_press_item_path = null;

        if (!same_item)
            return false;

        var entered_mode = false;
        if (!App.app.selection_mode)
            if (event.button == 3 || (event.button == 1 &&  Gdk.ModifierType.CONTROL_MASK in event.state)) {
                App.app.selection_mode = true;
                entered_mode = true;
            }

        if (App.app.selection_mode)
            return on_button_release_selection_mode (event, entered_mode, path);
        else
            return on_button_release_view_mode (event, path);
    }

    private bool on_button_release_selection_mode (Gdk.EventButton event, bool entered_mode, Gtk.TreePath path) {
        Gtk.TreeIter iter;
        if (!model.get_iter (out iter, path))
            return false;

        bool selected;
        model.get (iter, ModelColumns.SELECTED, out selected);

        if (selected && !entered_mode)
            model.set (iter, ModelColumns.SELECTED, false);
        else if (!selected)
            model.set (iter, ModelColumns.SELECTED, true);
        icon_view.queue_draw ();

//        App.app.notify_property ("selected-items");

        return false;
    }

    private bool on_button_release_view_mode (Gdk.EventButton event, Gtk.TreePath path) {
        Gtk.TreeIter iter;
        GLib.Value iter_id;
        GLib.Value iter_type;
        GLib.Value iter_media;

        model.get_iter (out iter, path);
        model.get_value (iter, Music.ModelColumns.ID, out iter_id);
        model.get_value (iter, Music.ModelColumns.TYPE, out iter_type);
        model.get_value (iter, Music.ModelColumns.MEDIA, out iter_media);

        var id = (string) iter_id;
        Music.ItemType? type = (Music.ItemType) iter_type;
        Grl.Media? media = (Grl.Media) iter_media;

        load_item (id, type);
        item_selected (id, type, media); 

        return false;
    }

    public void on_browse_back (string item_id, Music.ItemType? item_type) {
        load_item (item_id, item_type);
    }

    private void on_app_state_changed (Music.AppState old_state, Music.AppState new_state) {
        switch (new_state) {
            case Music.AppState.ARTISTS:
                App.app.browse_history.clear ();                    
                App.app.browse_history.push ("all_artists", null);
                model.load_item("all_artists", null);
                break;
            case Music.AppState.ALBUMS:
                App.app.browse_history.clear ();                    
                App.app.browse_history.push ("all_albums", null);
                model.load_item("all_albums", null);
                break;
            case Music.AppState.SONGS:
                App.app.browse_history.clear ();                    
                App.app.browse_history.push ("all_songs", null);
                model.load_item("all_songs", null);
                break;
            case Music.AppState.PLAYLISTS:
            case Music.AppState.PLAYLIST:
            case Music.AppState.PLAYLIST_NEW:
                break;
        }
    }

    private void load_item (string item_id, Music.ItemType? item_type) {
        model.load_item (item_id, item_type);

        if (item_type == null) {
            switch (item_id) {
                case "all_artists":
                    App.app.app_state_changed.disconnect (on_app_state_changed);
                    App.app.app_state = Music.AppState.ARTISTS;
                    App.app.app_state_changed.connect (on_app_state_changed);
                    break;
                case "all_albums":
                    App.app.app_state_changed.disconnect (on_app_state_changed);
                    App.app.app_state = Music.AppState.ALBUMS;
                    App.app.app_state_changed.connect (on_app_state_changed);
                    break;
                case "all_songs":
                    App.app.app_state_changed.disconnect (on_app_state_changed);
                    App.app.app_state = Music.AppState.SONGS;
                    App.app.app_state_changed.connect (on_app_state_changed);
                    break;
            }
        }
        else {
            switch (item_type) {
                case Music.ItemType.ARTIST:
                    App.app.app_state_changed.disconnect (on_app_state_changed);
                    App.app.app_state = Music.AppState.ALBUMS;
                    App.app.app_state_changed.connect (on_app_state_changed);
                    break;
                case Music.ItemType.ALBUM:
                    App.app.app_state_changed.disconnect (on_app_state_changed);
                    App.app.app_state = Music.AppState.SONGS;
                    App.app.app_state_changed.connect (on_app_state_changed);
                    break;
                case Music.ItemType.SONG:
                    break;
            }
        }
    }
}