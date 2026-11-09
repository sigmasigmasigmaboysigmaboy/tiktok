# tiktok_bot.py | discord.py 2.x | python 3.11+

import discord
from discord.ext import commands
import aiohttp
import os
from dotenv import load_dotenv

load_dotenv()

TOKEN   = os.getenv("DISCORD_TOKEN")
API_KEY = os.getenv("SMM_API_KEY")
API_URL = os.getenv("SMM_API_URL")

SERVICES = {
    "views":     "1001",
    "likes":     "1002",
    "followers": "1003",
    "favorites": "1004",
    "shares":    "1005",
}

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="!", intents=intents)


async def smm_order(service_id: str, link: str, quantity: int) -> dict:
    payload = {
        "key":      API_KEY,
        "action":   "add",
        "service":  service_id,
        "link":     link,
        "quantity": quantity,
    }
    async with aiohttp.ClientSession() as session:
        async with session.post(API_URL, data=payload, timeout=aiohttp.ClientTimeout(total=10)) as r:
            if r.status != 200:
                raise ValueError(f"panel returned HTTP {r.status}")
            data = await r.json()
            if "error" in data:
                raise ValueError(data["error"])
            return data


async def smm_balance() -> float:
    payload = {"key": API_KEY, "action": "balance"}
    async with aiohttp.ClientSession() as session:
        async with session.post(API_URL, data=payload, timeout=aiohttp.ClientTimeout(total=10)) as r:
            data = await r.json()
            return float(data.get("balance", 0))


def order_embed(action: str, link: str, qty: int, order_id) -> discord.Embed:
    e = discord.Embed(title="✅ Order Placed", color=0x00ff88)
    e.add_field(name="Type",     value=action.capitalize(), inline=True)
    e.add_field(name="Amount",   value=str(qty),            inline=True)
    e.add_field(name="Order ID", value=str(order_id),       inline=True)
    e.add_field(name="Link",     value=link,                inline=False)
    return e


def err_embed(msg: str) -> discord.Embed:
    return discord.Embed(title="❌ Error", description=msg, color=0xff4444)


async def handle_order(ctx, action: str, link: str, amount: int):
    if amount < 1 or amount > 100_000:
        await ctx.send(embed=err_embed("amount must be 1–100,000"))
        return
    if not link.startswith("https://"):
        await ctx.send(embed=err_embed("link must start with https://"))
        return
    try:
        result = await smm_order(SERVICES[action], link, amount)
        await ctx.send(embed=order_embed(action, link, amount, result.get("order", "?")))
    except ValueError as exc:
        await ctx.send(embed=err_embed(str(exc)))


@bot.command(name="views")
async def views(ctx, link: str, amount: int):
    await handle_order(ctx, "views", link, amount)

@bot.command(name="likes")
async def likes(ctx, link: str, amount: int):
    await handle_order(ctx, "likes", link, amount)

@bot.command(name="followers")
async def followers(ctx, user: str, amount: int):
    await handle_order(ctx, "followers", user, amount)

@bot.command(name="favorites")
async def favorites(ctx, link: str, amount: int):
    await handle_order(ctx, "favorites", link, amount)

@bot.command(name="shares")
async def shares(ctx, link: str, amount: int):
    await handle_order(ctx, "shares", link, amount)

@bot.command(name="stats")
async def stats(ctx):
    try:
        bal = await smm_balance()
        e = discord.Embed(title="📊 Stats", color=0x5865f2)
        e.add_field(name="Panel Balance", value=f"${bal:.4f}", inline=False)
        e.set_footer(text=f"requested by {ctx.author}")
        await ctx.send(embed=e)
    except Exception as exc:
        await ctx.send(embed=err_embed(str(exc)))

@bot.command(name="admin")
@commands.has_permissions(administrator=True)
async def admin(ctx):
    e = discord.Embed(title="🔧 Admin Panel", color=0xffa500)
    e.add_field(name="Commands", value="\n".join([
        "!views <link> <amount>",
        "!likes <link> <amount>",
        "!followers <user_url> <amount>",
        "!favorites <link> <amount>",
        "!shares <link> <amount>",
        "!stats",
    ]), inline=False)
    await ctx.send(embed=e)

@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.MissingRequiredArgument):
        await ctx.send(embed=err_embed(f"missing arg: `{error.param.name}`"))
    elif isinstance(error, commands.BadArgument):
        await ctx.send(embed=err_embed("bad argument — amount must be a number"))
    elif isinstance(error, commands.MissingPermissions):
        await ctx.send(embed=err_embed("admins only"))
    else:
        await ctx.send(embed=err_embed(f"unexpected: {error}"))

@bot.event
async def on_ready():
    print(f"[tiktok-bot] {bot.user} online")

bot.run(TOKEN)
