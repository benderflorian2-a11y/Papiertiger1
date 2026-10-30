package de.papiertiger.tiger.papiertiger

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Startbildschirm-Widget: zeigt, was als Nächstes fällig ist. Den Text schreibt die App
 * (SharedPreferences „flutter.widget_text“) nach jeder Änderung.
 */
class PapiertigerWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val titel = prefs.getString("flutter.widget_titel", null) ?: "Papiertiger"
        val text = prefs.getString("flutter.widget_text", null) ?: "Nichts offen. Der Tiger schläft entspannt."
        val oeffnen = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.papiertiger_widget)
            views.setTextViewText(R.id.widget_titel, titel)
            views.setTextViewText(R.id.widget_text, text)
            views.setOnClickPendingIntent(R.id.widget_wurzel, oeffnen)
            manager.updateAppWidget(id, views)
        }
    }
}
