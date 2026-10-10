package dev.fatsoenlijk.carplay

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.constraints.ConstraintManager
import androidx.car.app.model.*
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONArray
import org.json.JSONObject

/** Uses Android Auto's host templates; does not mirror the handset WebView. */
class CarScreen(context: CarContext, var document: JSONObject, private val actionOrigin: JSONObject? = null) : Screen(context) {
    private val store = CarEventStore.get(context)
    private var query = ""
    private var activeTab: String? = null
    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onResume(owner: LifecycleOwner) {
                CarRuntime.updateStatus(this@CarScreen)
                emit("templateAppeared", JSONObject().put("templateId", document.optString("id")))
            }
        })
    }
    private fun emit(type: String, payload: JSONObject) = store.emit(type, payload)
    private fun header(): Action = if (screenManager.stackSize > 1) Action.BACK else Action.APP_ICON
    private fun limit(type: Int): Int = if (carContext.carAppApiLevel >= 2) carContext.getCarService(ConstraintManager::class.java).getContentLimit(type).coerceAtLeast(1) else if (type == ConstraintManager.CONTENT_LIMIT_TYPE_PANE) 4 else 6
    private fun icon(name: String): CarIcon {
        val resource = when (name) {
            "search" -> android.R.drawable.ic_menu_search
            "map", "pin", "parking", "charging" -> android.R.drawable.ic_menu_mapmode
            "play", "music" -> android.R.drawable.ic_media_play
            "pause" -> android.R.drawable.ic_media_pause
            "star" -> android.R.drawable.btn_star_big_on
            "info" -> android.R.drawable.ic_menu_info_details
            "home" -> android.R.drawable.ic_menu_myplaces
            "food" -> android.R.drawable.ic_menu_compass
            "grid" -> android.R.drawable.ic_menu_gallery
            else -> android.R.drawable.ic_menu_agenda
        }
        return CarIcon.Builder(IconCompat.createWithResource(carContext, resource)).build()
    }
    private fun select(t: JSONObject, r: JSONObject) {
        emit("itemSelected", JSONObject().put("templateId", t.getString("id")).put("itemId", r.getString("id")).put("actionId", r.optString("action", r.getString("id"))))
    }
    private fun row(t: JSONObject, r: JSONObject, selectable: Boolean = true): Row {
        val builder = Row.Builder().setTitle(r.getString("title"))
        if (r.has("detail") && r.getString("detail").isNotEmpty()) builder.addText(r.getString("detail"))
        if (r.has("icon")) builder.setImage(icon(r.getString("icon")))
        if (selectable && r.optBoolean("enabled", true)) builder.setOnClickListener { select(t, r) }
        if (carContext.carAppApiLevel >= 5) builder.setEnabled(r.optBoolean("enabled", true))
        return builder.build()
    }
    private fun items(t: JSONObject, rows: List<JSONObject>, type: Int = ConstraintManager.CONTENT_LIMIT_TYPE_LIST): ItemList {
        val builder = ItemList.Builder().setNoItemsMessage("No items")
        rows.take(limit(type)).forEach { builder.addItem(row(t, it)) }
        return builder.build()
    }
    private fun action(t: JSONObject, a: JSONObject): Action = Action.Builder().setTitle(a.getString("title")).setOnClickListener {
        val payload = JSONObject().put("templateId", actionOrigin?.optString("templateId") ?: t.getString("id")).put("actionId", a.getString("id"))
        actionOrigin?.let { payload.put("pointId", it.getString("pointId")) }
        emit("actionPressed", payload)
    }.build()

    @Suppress("DEPRECATION")
    fun render(t: JSONObject, child: Boolean = false): Template {
        val title = t.getString("title")
        return when (t.getString("type")) {
            "list" -> {
                val builder = ListTemplate.Builder()
                if (!child) builder.setTitle(title).setHeaderAction(header())
                if (t.optBoolean("loading")) builder.setLoading(true)
                else {
                    val sections = CarContract.objects(t, "sections", 1, 10)
                    // Flatten untitled/mixed sections: Android requires named section lists.
                    var left = limit(ConstraintManager.CONTENT_LIMIT_TYPE_LIST)
                    val nonEmpty = sections.filter { it.getJSONArray("items").length() > 0 }
                    if (nonEmpty.size > 1 && nonEmpty.all { it.optString("title").isNotBlank() }) {
                        nonEmpty.forEach { s ->
                            if (left > 0) {
                                val rows = CarContract.objects(s, "items", 0, 100).take(left); left -= rows.size
                                builder.addSectionedList(SectionedItemList.create(items(t, rows), s.getString("title")))
                            }
                        }
                    } else builder.setSingleList(items(t, sections.flatMap { CarContract.objects(it, "items", 0, 100) }))
                }
                builder.build()
            }
            "grid" -> {
                val list = ItemList.Builder()
                CarContract.objects(t, "items", 1, 8).take(limit(ConstraintManager.CONTENT_LIMIT_TYPE_GRID)).forEach { r ->
                    val grid = GridItem.Builder().setTitle(r.getString("title")).setImage(icon(r.getString("icon")))
                    if (r.has("detail")) grid.setText(r.getString("detail"))
                    if (r.optBoolean("enabled", true)) grid.setOnClickListener { select(t, r) }
                    list.addItem(grid.build())
                }
                GridTemplate.Builder().setSingleList(list.build()).apply { if (!child) setTitle(title).setHeaderAction(header()) }.build()
            }
            "information" -> {
                val pane = Pane.Builder()
                CarContract.objects(t, "items", 1, 4).take(limit(ConstraintManager.CONTENT_LIMIT_TYPE_PANE)).forEach { pane.addRow(row(t, it, false)) }
                CarContract.actions(t).forEach { pane.addAction(action(t, it)) }
                PaneTemplate.Builder(pane.build()).apply { if (!child) setTitle(title).setHeaderAction(header()) }.build()
            }
            "message" -> MessageTemplate.Builder(t.getString("message")).apply {
                if (!child) setTitle(title).setHeaderAction(header())
                CarContract.actions(t).forEach { addAction(action(t, it)) }
            }.build()
            "search" -> {
                val callback = object : SearchTemplate.SearchCallback {
                    override fun onSearchTextChanged(searchText: String) {
                        query = searchText.take(128)
                        emit("searchChanged", JSONObject().put("templateId", t.getString("id")).put("query", query)); invalidate()
                    }
                    override fun onSearchSubmitted(searchText: String) {
                        emit("searchSubmitted", JSONObject().put("templateId", t.getString("id")).put("query", searchText.take(128)))
                    }
                }
                val results = CarContract.objects(t, "items", 0, 100).filter { query.isEmpty() || it.getString("title").contains(query, ignoreCase = true) }
                SearchTemplate.Builder(callback).setSearchHint(t.optString("hint", "Search")).setInitialSearchText(query).setItemList(items(t, results)).apply { if (!child) setHeaderAction(header()) }.build()
            }
            "tabs" -> {
                if (carContext.carAppApiLevel < 6) throw CarFailure("UNSUPPORTED", "Tabs require Car App API 6.")
                val tabs = CarContract.objects(t, "tabs", 2, 4)
                val chosen = tabs.firstOrNull { it.getString("id") == activeTab } ?: tabs.first()
                activeTab = chosen.getString("id")
                TabTemplate.Builder(object : TabTemplate.TabCallback {
                    override fun onTabSelected(tabContentId: String) {
                        activeTab = tabContentId
                        emit("tabSelected", JSONObject().put("templateId", t.getString("id")).put("tabId", tabContentId)); invalidate()
                    }
                }).setHeaderAction(Action.APP_ICON).setActiveTabContentId(activeTab!!).setTabContents(TabContents.Builder(render(chosen, true)).build()).apply {
                    tabs.forEach { addTab(Tab.Builder().setTitle(it.getString("title")).setContentId(it.getString("id")).setIcon(icon(it.optString("icon", "list"))).build()) }
                }.build()
            }
            "poi" -> {
                val list = ItemList.Builder()
                CarContract.objects(t, "points", 1, 6).take(limit(ConstraintManager.CONTENT_LIMIT_TYPE_PLACE_LIST)).forEach { p ->
                    val (lat, lon) = CarContract.coordinate(p)
                    val place = Place.Builder(CarLocation.create(lat, lon)).setMarker(PlaceMarker.Builder().build()).build()
                    list.addItem(Row.Builder().setTitle(p.getString("title")).apply { if (p.optString("subtitle").isNotBlank()) addText(p.getString("subtitle")) }
                        .setMetadata(Metadata.Builder().setPlace(place).build()).setBrowsable(true).setOnClickListener {
                            emit("pointSelected", JSONObject().put("templateId", t.getString("id")).put("pointId", p.getString("id")))
                            val detail = JSONObject().put("id", p.getString("id").take(120) + ":detail").put("type", "information").put("title", p.getString("title"))
                                .put("items", JSONArray().put(JSONObject().put("title", p.getString("title")).put("detail", p.optString("summary", p.optString("subtitle")))))
                                .put("actions", p.optJSONArray("actions") ?: JSONArray())
                            if (screenManager.stackSize < 5) screenManager.push(CarScreen(carContext, detail, JSONObject().put("templateId", t.getString("id")).put("pointId", p.getString("id"))))
                        }.build())
                }
                PlaceListMapTemplate.Builder().setTitle(title).setHeaderAction(header()).setItemList(list.build()).apply {
                    if (carContext.carAppApiLevel >= 5) setOnContentRefreshListener { emit("contentRefreshRequested", JSONObject().put("templateId", t.getString("id"))) }
                }.build()
            }
            else -> throw CarFailure("UNSUPPORTED", "${t.getString("type")} is not supported by Android Auto.")
        }
    }
    @Suppress("DEPRECATION")
    override fun onGetTemplate(): Template = try { render(document) } catch (e: Exception) {
        // A host must receive a valid template even if an OEM rejects model constraints.
        store.emit("error", JSONObject().put("code", "TEMPLATE_REJECTED").put("message", e.message ?: "Template rejected."))
        MessageTemplate.Builder("Content is unavailable. Open the app on your phone.").setTitle("NativePHP").setHeaderAction(header()).build()
    }
}
