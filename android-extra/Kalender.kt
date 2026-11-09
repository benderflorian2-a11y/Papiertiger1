package de.papiertiger.tiger.papiertiger

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.provider.CalendarContract
import java.util.TimeZone

/** Trägt Termine direkt in den Kalender des Handys ein (Google-Kalender, Samsung-Kalender usw.). */
object Kalender {
    /** Eigener Hauptkalender des Nutzers, sonst der erste beschreibbare. */
    private fun kalenderId(c: Context): Long? {
        val spalten = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.OWNER_ACCOUNT,
        )
        val auswahl = "${CalendarContract.Calendars.VISIBLE} = 1 AND " +
            "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ${CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR}"
        c.contentResolver.query(CalendarContract.Calendars.CONTENT_URI, spalten, auswahl, null, null)?.use { cur ->
            var erste: Long? = null
            while (cur.moveToNext()) {
                val id = cur.getLong(0)
                if (erste == null) erste = id
                if (cur.getString(1) != null && cur.getString(1) == cur.getString(2)) return id
            }
            return erste
        }
        return null
    }

    private fun existiert(c: Context, id: Long): Boolean {
        c.contentResolver.query(
            ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id),
            arrayOf(CalendarContract.Events._ID, CalendarContract.Events.DELETED), null, null, null,
        )?.use { cur ->
            return cur.moveToFirst() && cur.getInt(1) == 0
        }
        return false
    }

    /**
     * Legt einen Termin an oder ändert ihn (wenn [eventId] > 0).
     * Ganztägig: [startMs] ist Mitternacht UTC des Tages. Gibt die Termin-Nummer zurück,
     * -1 = kein Kalender gefunden, -2 = der Termin wurde vom Nutzer gelöscht.
     */
    fun eintragen(
        c: Context, titel: String, beschreibung: String, startMs: Long, ganztags: Boolean,
        erinnerungMinuten: List<Int>, eventId: Long,
    ): Long {
        if (eventId > 0 && !existiert(c, eventId)) return -2
        val werte = ContentValues().apply {
            put(CalendarContract.Events.TITLE, titel)
            put(CalendarContract.Events.DESCRIPTION, beschreibung)
            put(CalendarContract.Events.DTSTART, startMs)
            put(CalendarContract.Events.DTEND, startMs + if (ganztags) 86_400_000L else 3_600_000L)
            put(CalendarContract.Events.ALL_DAY, if (ganztags) 1 else 0)
            put(CalendarContract.Events.EVENT_TIMEZONE, if (ganztags) "UTC" else TimeZone.getDefault().id)
        }
        val id: Long
        if (eventId > 0) {
            c.contentResolver.update(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId), werte, null, null)
            id = eventId
            c.contentResolver.delete(
                CalendarContract.Reminders.CONTENT_URI,
                "${CalendarContract.Reminders.EVENT_ID} = ?", arrayOf(id.toString()),
            )
        } else {
            val kalender = kalenderId(c) ?: return -1
            werte.put(CalendarContract.Events.CALENDAR_ID, kalender)
            val uri = c.contentResolver.insert(CalendarContract.Events.CONTENT_URI, werte) ?: return -1
            id = ContentUris.parseId(uri)
        }
        for (min in erinnerungMinuten) {
            val r = ContentValues().apply {
                put(CalendarContract.Reminders.EVENT_ID, id)
                put(CalendarContract.Reminders.MINUTES, min)
                put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
            }
            c.contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, r)
        }
        return id
    }

    fun loeschen(c: Context, id: Long): Boolean =
        c.contentResolver.delete(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id), null, null) > 0
}
