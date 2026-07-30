import { supabase, GALLERY_BUCKET } from './supabase';

export interface GalleryImage {
  id: string;
  storage_path: string;
  alt: string | null;
  sort_order: number;
  album_id: string | null;
  created_at: string;
  url: string; // aufgelöste öffentliche URL
}

export interface GalleryAlbum {
  id: string;
  title: string;
  description: string | null;
  sort_order: number;
  created_at: string;
  updated_at: string;
  images: GalleryImage[];
}

/** Bucket-Pfad -> öffentliche URL (synchron, kein Netzwerk-Call). */
export function publicUrl(path: string): string {
  return supabase.storage.from(GALLERY_BUCKET).getPublicUrl(path).data.publicUrl;
}

/** Alle Alben inkl. ihrer Bilder, beides nach sort_order sortiert. */
export async function getAlbums(): Promise<GalleryAlbum[]> {
  const { data, error } = await supabase
    .from('gallery_albums')
    .select(
      'id, title, description, sort_order, created_at, updated_at,' +
      'gallery_images ( id, storage_path, alt, sort_order, album_id, created_at )'
    )
    .order('sort_order', { ascending: true })
    // Reihenfolge der eingebetteten Bilder. In älteren supabase-js-Versionen
    // heisst die Option 'foreignTable' statt 'referencedTable'.
    .order('sort_order', { ascending: true, referencedTable: 'gallery_images' });

  if (error) throw new Error(`Galerie-Alben konnten nicht geladen werden: ${error.message}`);

  return (data ?? []).map((album: any) => ({
    ...album,
    images: (album.gallery_images ?? []).map((img: GalleryImage) => ({
      ...img,
      url: publicUrl(img.storage_path),
    })),
  }));
}

/** Bilder, die (noch) keinem Album zugeordnet sind. */
export async function getUnassignedImages(): Promise<GalleryImage[]> {
  const { data, error } = await supabase
    .from('gallery_images')
    .select('id, storage_path, alt, sort_order, album_id, created_at')
    .is('album_id', null)
    .order('sort_order', { ascending: true });

  if (error) throw new Error(`Lose Bilder konnten nicht geladen werden: ${error.message}`);

  return (data ?? []).map((img) => ({ ...img, url: publicUrl(img.storage_path) }));
}