package com.vijay_sharma.whatsapp_share_plus

import androidx.core.content.FileProvider

/**
 * A [FileProvider] subclass owned by this plugin.
 *
 * Sharing files needs a provider, but declaring one against the plain
 * `FileProvider` class risks colliding with the host app's own provider
 * declaration. A dedicated subclass with a plugin-scoped authority keeps the
 * two independent.
 */
class WhatsappSharePlusProvider : FileProvider()
