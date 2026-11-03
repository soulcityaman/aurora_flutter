package com.aurora.music

import android.app.Application
import androidx.media3.common.util.UnstableApi
import com.aurora.music.audio.EngineRegistry
import com.aurora.music.audio.SpatialAudio
import com.aurora.music.audio.analysis.AudioFeatureHub
import com.aurora.music.data.LibraryRepository
import com.aurora.music.data.sources.SourceRegistry
import com.aurora.music.data.sources.jiosaavn.JioSaavnSource
import com.aurora.music.data.sources.youtube.YouTubeMusicSource
import com.aurora.music.playback.PlayerController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient

class MusicApp : Application() {
    val graph: AppGraph by lazy { AppGraph(this) }
}

@UnstableApi
class AppGraph(app: Application) {
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val http = OkHttpClient.Builder().retryOnConnectionFailure(true).build()

    val sources = SourceRegistry(listOf(JioSaavnSource(http), YouTubeMusicSource(http)))
    val library = LibraryRepository(app, appScope, sources)
    val player = PlayerController(app)
    val features = AudioFeatureHub(app, appScope).also { it.start() }
    val spatial = SpatialAudio(app)

    init {
        appScope.launch { EngineRegistry.engine.collect { e -> if (e != null) spatial.apply(e) } }
    }
}
