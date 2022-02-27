"""
Applet: NFT
Summary: Random Opensea NFT
Description: Displays a random NFT associated with an Ethereum public address.
Author: nipterink
"""

load("cache.star", "cache")
load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("secret.star", "secret")
load("time.star", "time")

ASSETS_URL = "https://api.opensea.io/api/v1/assets?format=json&owner={}"
COLLECTION_URL = "https://api.opensea.io/api/v1/collection/{}/"

def main(config):
    api_key = secret.decrypt("AV6+xWcEAJh6U3VcNQPxFbXfOyADTC0TQJxUEtd9xUoWMJNEvLLSsLgvXxnpECEEVCuYVK0fQLUDot4yz5PPs8jIuCXlmfFs0BrSjfPSs0eS8RYgM6ZQfoMSo6Oo3Vs6RyuVW7U2P5jS5VhdyqipdJ1bQHcyoRT67JiARa6TuuaWzOmXHrU=") or config.get("opensea-api-key") or ""
    public_address = config.get("public_address") or "0xd6a984153acb6c9e2d788f08c2465a1358bb89a7"
    nfts = fetch_opensea_assets(public_address, api_key)
    nft = nfts[random(len(nfts))]
    (nft_name, nft_thumbnail) = fetch_nft_thumbnail(nft)
    collection_stats = fetch_collection_stats(nft)

    return render.Root(
        child = render.Box(
            child = render.Column(
                cross_align = "center",
                children = [
                    render.Marquee(
                        offset_start = 64,
                        width = 64,
                        child = render.Text(nft_name),
                    ),
                    render.Row(
                        cross_align = "center",
                        children = [
                            render.Image(
                                src = nft_thumbnail,
                                height = 24,
                                width = 24,
                            ),
                            render.Text(" Ξ%s" % collection_stats["floor_price"]),
                        ],
                    ),
                ],
            ),
        ),
    )

def fetch_opensea_assets(public_address, api_key):
    cached_nfts = cache.get("public_address=%s" % public_address)
    if cached_nfts != None:
        print("Hit! Using cached Opensea response for", public_address)
        nfts = json.decode(cached_nfts)
    else:
        fetch_url = ASSETS_URL.format(public_address)
        print("Miss! Fetching OpenSea Assets for", public_address)
        assets_resp = http.get(fetch_url, headers = {"X-API-KEY": api_key})
        if (assets_resp.status_code != 200):
            fail("OpenSea request failed with status", assets_resp.status_code)

        nfts = assets_resp.json()["assets"]
        cache.set("public_address=%s" % public_address, json.encode(nfts), ttl_seconds = 3600)

    return nfts

def fetch_nft_thumbnail(nft):
    nft_name = nft["name"]
    thumbnail_url = nft["image_thumbnail_url"]
    cached_thumbnail = cache.get("thumbnail=%s" % thumbnail_url)
    if cached_thumbnail != None:
        print("Hit! Using cached thumbnail for", nft_name)
        return (nft_name, base64.decode(cached_thumbnail))
    else:
        print("Miss! Fetching image thumbnail for", nft_name)
        thumbnail_resp = http.get(thumbnail_url)
        if (thumbnail_resp.status_code != 200):
            fail("Failed to fetch thumbnail with status", thumbnail_resp.status_code)
        cache.set("thumbnail=%s" % thumbnail_url, base64.encode(thumbnail_resp.body()), ttl_seconds = 3600)
        return (nft_name, thumbnail_resp.body())

def fetch_collection_stats(nft):
    collection_slug = nft["collection"]["slug"]
    cached_collection_stats = cache.get("collection=%s" % collection_slug)
    if cached_collection_stats != None:
        print("Hit! Using cached collection stats for", collection_slug)
        return json.decode(cached_collection_stats)
    else:
        collection_url = COLLECTION_URL.format(collection_slug)
        print("Miss! Fetching OpenSea stats for", collection_slug)
        collection_resp = http.get(collection_url)
        if (collection_resp.status_code != 200):
            fail("OpenSea request failed with status", collection_resp.status_code)

        collection_stats = collection_resp.json()["collection"]["stats"]
        cache.set("collection=%s" % collection_slug, json.encode(collection_stats), ttl_seconds = 3600)
        return collection_stats

def random(max):
    """Return a pseudo-random number in [0, max)"""
    return int(time.now().nanosecond % max)

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "public_address",
                name = "Public Address",
                desc = "Ethereum Public Address",
                icon = "ethereum",
                default = "0xd6a984153acb6c9e2d788f08c2465a1358bb89a7",
            ),
        ],
    )
