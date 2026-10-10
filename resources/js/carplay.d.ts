export type Icon = 'list' | 'grid' | 'search' | 'map' | 'pin' | 'parking' | 'charging' | 'food' | 'music' | 'play' | 'pause' | 'info' | 'star' | 'home';
export interface Item { id: string; title: string; detail?: string; icon?: Icon; action?: string; enabled?: boolean }
export interface CarAction { id: string; title: string; style?: 'normal' | 'cancel' | 'destructive' }
export interface Base { id: string; title: string; icon?: Icon }
export interface ListTemplate extends Base { type: 'list'; sections: { title?: string; items: Item[] }[]; loading?: boolean }
export interface GridTemplate extends Base { type: 'grid'; items: (Item & { icon: Icon })[] }
export interface InformationTemplate extends Base { type: 'information'; items: { title: string; detail?: string }[]; actions?: CarAction[] }
export interface MessageTemplate extends Base { type: 'message'; message: string; actions?: CarAction[] }
export interface SearchTemplate extends Base { type: 'search'; items: Item[]; hint?: string }
export interface TabsTemplate extends Base { type: 'tabs'; tabs: (ListTemplate | GridTemplate)[] }
export interface Point { id: string; title: string; latitude: number; longitude: number; subtitle?: string; summary?: string; actions?: CarAction[] }
export interface PoiTemplate extends Base { type: 'poi'; points: Point[] }
export interface AlertTemplate extends Base { type: 'alert'; actions: CarAction[] }
export interface NowPlayingTemplate extends Base { type: 'nowPlaying' }
export type Template = ListTemplate | GridTemplate | InformationTemplate | MessageTemplate | SearchTemplate | TabsTemplate | PoiTemplate | AlertTemplate | NowPlayingTemplate;
export interface Accepted { accepted: true; operationId: string }
export interface CarEvent { id: string; type: string; platform: 'carplay' | 'androidAuto'; timestamp: number; payload: Record<string, unknown> }
export interface Status { connected: boolean; platform: 'carplay' | 'androidAuto'; depth: number; cachedRoot: boolean; persistenceError: string | null; templateId?: string | null; carAppApiLevel?: number }
export interface Capabilities { carAppApiLevel?: number; platform: 'carplay' | 'androidAuto'; category: string; templates: Template['type'][]; replace: Template['type'][]; modalAlerts: boolean; navigationHandoff: boolean; embeddedNavigation: false; audioPlayback: false; durableEvents: boolean; maxDepth: number; icons: Icon[]; requiresCarApi?: Record<string, number> }
export interface CarPlayApi {
  capabilities(): Promise<Capabilities>; status(): Promise<Status>;
  setRoot(template: Template): Promise<Accepted>; push(template: Template): Promise<Accepted>; replace(template: Template): Promise<Accepted>;
  pop(): Promise<Accepted>; popToRoot(): Promise<Accepted>; present(template: AlertTemplate): Promise<Accepted>; dismiss(): Promise<Accepted>; clear(): Promise<Accepted>;
  navigate(latitude: number, longitude: number, name?: string): Promise<Accepted>;
  events(limit?: number): Promise<{ events: CarEvent[]; dropped: number }>;
  acknowledge(ids: string[]): Promise<{ acknowledged: number; persisted: boolean }>; bindEvents(): Promise<{ bound: boolean }>;
}
export class CarPlayError extends Error { code: string; constructor(code: string, message: string) }
export function createCarPlay(options?: { fetch?: typeof fetch; endpoint?: string }): CarPlayApi;
export const CarPlay: CarPlayApi;
