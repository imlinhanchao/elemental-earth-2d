#!/usr/bin/env python3
import os

ICONS_DIR = "/Users/hancel/Documents/project/elemental-earth-2d/assets/icons"
os.makedirs(ICONS_DIR, exist_ok=True)

icons = {
    # 1. 实验 (Experiment / Lab) - 烧瓶药水与原子环 (参考图中央烧瓶)
    "tab_lab.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="flaskGlass" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#C084FC" stop-opacity="0.9"/>
      <stop offset="100%" stop-color="#38BDF8" stop-opacity="0.8"/>
    </linearGradient>
    <linearGradient id="liquidGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#C084FC"/>
      <stop offset="50%" stop-color="#9333EA"/>
      <stop offset="100%" stop-color="#581C87"/>
    </linearGradient>
    <radialGradient id="ringGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#E9D5FF" stop-opacity="0.9"/>
      <stop offset="100%" stop-color="#A855F7" stop-opacity="0.2"/>
    </radialGradient>
  </defs>
  <!-- 烧瓶瓶身底板 -->
  <path d="M26 6 h12 v12 l14 26 c3 5.5 -1 12 -7 12 H19 c-6 0 -10 -6.5 -7 -12 L26 18 Z" 
        fill="#161936" stroke="#38BDF8" stroke-width="2.5" stroke-linejoin="round"/>
  <!-- 药水填充 -->
  <path d="M15 42 Q24 37 32 40 T49 42 L52 48 c1.5 3.5 -1 8 -5 8 H17 c-4 0 -6.5 -4.5 -5 -8 Z" 
        fill="url(#liquidGrad)"/>
  <!-- 药水高光气泡 -->
  <circle cx="26" cy="47" r="2.5" fill="#E9D5FF" opacity="0.8"/>
  <circle cx="38" cy="44" r="1.8" fill="#E9D5FF" opacity="0.9"/>
  <circle cx="32" cy="50" r="1.5" fill="#C084FC" opacity="0.7"/>
  <!-- 倾斜星环围绕 (参考图中环绕大烧瓶的光环) -->
  <ellipse cx="32" cy="36" rx="28" ry="8" fill="none" stroke="url(#flaskGlass)" stroke-width="3" 
           transform="rotate(-18 32 36)"/>
  <!-- 瓶口瓶盖木塞 -->
  <rect x="25" y="4" width="14" height="4" rx="2" fill="#F59E0B" stroke="#D97706" stroke-width="1.5"/>
  <!-- 玻璃高光 -->
  <path d="M22 47 A16 16 0 0 1 20 36" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" fill="none" opacity="0.6"/>
</svg>""",

    # 实验台图标 (兼容 lab.svg)
    "lab.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="liquidGrad2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#38BDF8"/>
      <stop offset="100%" stop-color="#0284C7"/>
    </linearGradient>
  </defs>
  <path d="M26 6 h12 v12 l14 26 c3 5.5 -1 12 -7 12 H19 c-6 0 -10 -6.5 -7 -12 L26 18 Z" 
        fill="#12142B" stroke="#A855F7" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M15 42 Q24 37 32 40 T49 42 L52 48 c1.5 3.5 -1 8 -5 8 H17 c-4 0 -6.5 -4.5 -5 -8 Z" 
        fill="url(#liquidGrad2)"/>
  <circle cx="26" cy="47" r="2.5" fill="#BAE6FD" opacity="0.8"/>
  <circle cx="38" cy="44" r="1.8" fill="#BAE6FD" opacity="0.9"/>
  <ellipse cx="32" cy="36" rx="28" ry="8" fill="none" stroke="#C084FC" stroke-width="2.5" transform="rotate(-18 32 36)"/>
  <rect x="25" y="4" width="14" height="4" rx="2" fill="#F59E0B"/>
</svg>""",

    # 2. 制作 (Crafting / Tools) - 双十字矿镐与战锤 (参考图左下挖矿与工具)
    "tab_craft.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="toolPick" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38BDF8"/>
      <stop offset="100%" stop-color="#0284C7"/>
    </linearGradient>
    <linearGradient id="toolWood" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FBBF24"/>
      <stop offset="100%" stop-color="#B45309"/>
    </linearGradient>
  </defs>
  <!-- 木柄 -->
  <line x1="12" y1="52" x2="48" y2="16" stroke="url(#toolWood)" stroke-width="5" stroke-linecap="round"/>
  <!-- 镐头弧形双刃 (青色发光金属) -->
  <path d="M28 8 C38 12 50 20 54 32 L47 34 C43 25 35 19 26 15 Z" fill="url(#toolPick)" stroke="#E0F2FE" stroke-width="1.5"/>
  <path d="M48 16 C38 26 30 38 24 48 L22 43 C26 33 34 23 43 14 Z" fill="none" stroke="#A855F7" stroke-width="1.5" opacity="0.7"/>
  <!-- 镐眼加固箍 -->
  <rect x="36" y="24" width="8" height="8" rx="2" transform="rotate(-45 40 28)" fill="#E2E8F0" stroke="#475569" stroke-width="1.5"/>
  <!-- 镐尖火星 -->
  <polygon points="56,30 58,26 62,28 58,32" fill="#FBBF24"/>
</svg>""",

    "tools.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="toolPick2" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#C084FC"/>
      <stop offset="100%" stop-color="#7E22CE"/>
    </linearGradient>
  </defs>
  <line x1="12" y1="52" x2="48" y2="16" stroke="#D97706" stroke-width="5" stroke-linecap="round"/>
  <path d="M28 8 C38 12 50 20 54 32 L47 34 C43 25 35 19 26 15 Z" fill="url(#toolPick2)" stroke="#F3E8FF" stroke-width="1.5"/>
  <rect x="36" y="24" width="8" height="8" rx="2" transform="rotate(-45 40 28)" fill="#E2E8F0" stroke="#475569" stroke-width="1.5"/>
  <polygon points="56,30 58,26 62,28 58,32" fill="#38BDF8"/>
</svg>""",

    # 3. 建造 (Building / Furnace) - 经典石砌熔炉 (参考图底部冶炼高炉)
    "tab_build.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="kilnStone" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#475569"/>
      <stop offset="100%" stop-color="#1E293B"/>
    </linearGradient>
    <radialGradient id="fireGlow" cx="50%" cy="80%" r="60%">
      <stop offset="0%" stop-color="#FEF08A"/>
      <stop offset="40%" stop-color="#F97316"/>
      <stop offset="100%" stop-color="#9A3412"/>
    </radialGradient>
  </defs>
  <!-- 顶部烟囱口 -->
  <rect x="26" y="8" width="12" height="6" rx="2" fill="#334155" stroke="#64748B" stroke-width="1.5"/>
  <!-- 炉身拱顶 -->
  <path d="M14 54 C12 36 22 14 32 14 C42 14 52 36 50 54 Z" fill="url(#kilnStone)" stroke="#64748B" stroke-width="2"/>
  <!-- 炉底基座石板 -->
  <rect x="10" y="52" width="44" height="6" rx="3" fill="#0F172A" stroke="#334155" stroke-width="1.5"/>
  <!-- 拱形燃烧炉门 (炽热熔火光芒) -->
  <path d="M22 52 C22 38 42 38 42 52 Z" fill="url(#fireGlow)"/>
  <!-- 炉膛火苗核心 -->
  <path d="M28 52 C28 44 32 42 32 42 C32 42 36 44 36 52 Z" fill="#FEF08A"/>
</svg>""",

    "furnace.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="kilnStone2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#475569"/>
      <stop offset="100%" stop-color="#1E293B"/>
    </linearGradient>
    <radialGradient id="fireGlow2" cx="50%" cy="80%" r="60%">
      <stop offset="0%" stop-color="#FEF08A"/>
      <stop offset="40%" stop-color="#F97316"/>
      <stop offset="100%" stop-color="#9A3412"/>
    </radialGradient>
  </defs>
  <rect x="26" y="8" width="12" height="6" rx="2" fill="#334155" stroke="#64748B" stroke-width="1.5"/>
  <path d="M14 54 C12 36 22 14 32 14 C42 14 52 36 50 54 Z" fill="url(#kilnStone2)" stroke="#64748B" stroke-width="2"/>
  <rect x="10" y="52" width="44" height="6" rx="3" fill="#0F172A" stroke="#334155" stroke-width="1.5"/>
  <path d="M22 52 C22 38 42 38 42 52 Z" fill="url(#fireGlow2)"/>
  <path d="M28 52 C28 44 32 42 32 42 C32 42 36 44 36 52 Z" fill="#FEF08A"/>
</svg>""",

    # 4. 生产 (Production / Automation) - 原子轨道与合成核心 (参考图右下合成新元素)
    "tab_production.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="atomGlow" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FDE047"/>
      <stop offset="50%" stop-color="#F97316"/>
      <stop offset="100%" stop-color="#EC4899"/>
    </linearGradient>
    <radialGradient id="coreGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="40%" stop-color="#FDE047"/>
      <stop offset="100%" stop-color="#F97316"/>
    </radialGradient>
  </defs>
  <!-- 3 条交叉旋转的原子电子轨道 -->
  <ellipse cx="32" cy="32" rx="26" ry="10" fill="none" stroke="url(#atomGlow)" stroke-width="2.5" transform="rotate(0 32 32)"/>
  <ellipse cx="32" cy="32" rx="26" ry="10" fill="none" stroke="url(#atomGlow)" stroke-width="2.5" transform="rotate(60 32 32)"/>
  <ellipse cx="32" cy="32" rx="26" ry="10" fill="none" stroke="url(#atomGlow)" stroke-width="2.5" transform="rotate(120 32 32)"/>
  <!-- 中心发光原子核 (高亮发光能量球) -->
  <circle cx="32" cy="32" r="7" fill="url(#coreGlow)"/>
  <!-- 轨道上的电子节点微粒 -->
  <circle cx="56" cy="32" r="2.5" fill="#FEF08A"/>
  <circle cx="20" cy="11" r="2.5" fill="#FEF08A"/>
  <circle cx="20" cy="53" r="2.5" fill="#FEF08A"/>
</svg>""",

    # 反应塔建筑 (reactor.svg)
    "reactor.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="towerMetal" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#334155"/>
      <stop offset="50%" stop-color="#64748B"/>
      <stop offset="100%" stop-color="#1E293B"/>
    </linearGradient>
    <linearGradient id="reactorFluid" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#38BDF8"/>
      <stop offset="100%" stop-color="#9333EA"/>
    </linearGradient>
  </defs>
  <rect x="22" y="8" width="20" height="46" rx="4" fill="url(#towerMetal)" stroke="#94A3B8" stroke-width="2"/>
  <!-- 玻璃反应观测视窗 -->
  <rect x="26" y="16" width="12" height="26" rx="3" fill="#0F172A" stroke="#38BDF8" stroke-width="1.5"/>
  <rect x="28" y="24" width="8" height="16" rx="2" fill="url(#reactorFluid)"/>
  <!-- 能量螺旋环圈 -->
  <path d="M20 22 C32 18 32 26 44 22" stroke="#C084FC" stroke-width="2" fill="none"/>
  <path d="M20 34 C32 30 32 38 44 34" stroke="#38BDF8" stroke-width="2" fill="none"/>
  <!-- 底部工业法兰座板 -->
  <rect x="14" y="52" width="36" height="6" rx="2" fill="#0F172A" stroke="#475569" stroke-width="1.5"/>
</svg>""",

    # 5. 行囊 (Backpack) - 炼金背包配青色发光锁扣
    "tab_inventory.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="packLeather" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#854D0E"/>
      <stop offset="100%" stop-color="#451A03"/>
    </linearGradient>
  </defs>
  <!-- 提手 -->
  <path d="M24 16 C24 10 40 10 40 16" fill="none" stroke="#F59E0B" stroke-width="3" stroke-linecap="round"/>
  <!-- 包体 -->
  <rect x="14" y="16" width="36" height="38" rx="8" fill="url(#packLeather)" stroke="#F59E0B" stroke-width="2"/>
  <!-- 包盖翻折 -->
  <path d="M14 16 h36 v14 C40 34 24 34 14 30 Z" fill="#78350F" stroke="#FBBF24" stroke-width="1.5"/>
  <!-- 炼金青蓝发光扣带 -->
  <rect x="28" y="24" width="8" height="12" rx="3" fill="#161936" stroke="#38BDF8" stroke-width="2"/>
  <circle cx="32" cy="30" r="2" fill="#38BDF8"/>
  <!-- 侧袋 -->
  <rect x="10" y="28" width="4" height="18" rx="2" fill="#581C87"/>
  <rect x="50" y="28" width="4" height="18" rx="2" fill="#581C87"/>
</svg>""",

    "backpack.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="packLeather2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#854D0E"/>
      <stop offset="100%" stop-color="#451A03"/>
    </linearGradient>
  </defs>
  <path d="M24 16 C24 10 40 10 40 16" fill="none" stroke="#F59E0B" stroke-width="3" stroke-linecap="round"/>
  <rect x="14" y="16" width="36" height="38" rx="8" fill="url(#packLeather2)" stroke="#F59E0B" stroke-width="2"/>
  <path d="M14 16 h36 v14 C40 34 24 34 14 30 Z" fill="#78350F" stroke="#FBBF24" stroke-width="1.5"/>
  <rect x="28" y="24" width="8" height="12" rx="3" fill="#161936" stroke="#38BDF8" stroke-width="2"/>
  <circle cx="32" cy="30" r="2" fill="#38BDF8"/>
</svg>""",

    # 6. 工具系列 (Tool Icons)
    # 原始燧石斧 (Flint Axe)
    "tool_flint_axe.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="flintBlade" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#64748B"/>
      <stop offset="100%" stop-color="#0F172A"/>
    </linearGradient>
  </defs>
  <!-- 木柄 -->
  <line x1="16" y1="52" x2="44" y2="18" stroke="#B45309" stroke-width="6" stroke-linecap="round"/>
  <!-- 燧石刀刃 (多边棱角锋利) -->
  <polygon points="36,12 54,6 52,24 38,28 34,18" fill="url(#flintBlade)" stroke="#38BDF8" stroke-width="2"/>
  <!-- 捆扎皮绳 -->
  <line x1="36" y1="18" x2="42" y2="24" stroke="#FBBF24" stroke-width="2.5"/>
  <line x1="40" y1="16" x2="38" y2="26" stroke="#FBBF24" stroke-width="2.5"/>
</svg>""",

    # 粗制石镐 (Stone Pickaxe)
    "tool_stone_pickaxe.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="stoneHead" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#94A3B8"/>
      <stop offset="100%" stop-color="#334155"/>
    </linearGradient>
  </defs>
  <line x1="14" y1="52" x2="46" y2="18" stroke="#92400E" stroke-width="5.5" stroke-linecap="round"/>
  <!-- 弧形坚石镐头 -->
  <path d="M26 12 C36 14 48 20 54 32 L46 34 C42 26 34 20 24 18 Z" fill="url(#stoneHead)" stroke="#CBD5E1" stroke-width="2"/>
  <rect x="34" y="24" width="8" height="8" rx="2" transform="rotate(-45 38 28)" fill="#64748B" stroke="#CBD5E1" stroke-width="1.5"/>
</svg>""",

    # 纯铜地质镐 (Copper Pickaxe - 铜橙色金属光泽)
    "tool_copper_pickaxe.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="copperHead" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FDBA74"/>
      <stop offset="50%" stop-color="#EA580C"/>
      <stop offset="100%" stop-color="#7C2D12"/>
    </linearGradient>
  </defs>
  <line x1="14" y1="52" x2="46" y2="18" stroke="#78350F" stroke-width="5.5" stroke-linecap="round"/>
  <path d="M26 12 C36 14 48 20 54 32 L46 34 C42 26 34 20 24 18 Z" fill="url(#copperHead)" stroke="#FED7AA" stroke-width="2"/>
  <rect x="34" y="24" width="8" height="8" rx="2" transform="rotate(-45 38 28)" fill="#C2410C" stroke="#FED7AA" stroke-width="1.5"/>
  <polygon points="56,30 58,26 62,28 58,32" fill="#FDBA74"/>
</svg>""",

    # 精钢地质重锤 (Steel Hammer - 银蓝高精锻锤)
    "tool_iron_hammer.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="steelHead" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#E2E8F0"/>
      <stop offset="50%" stop-color="#64748B"/>
      <stop offset="100%" stop-color="#1E293B"/>
    </linearGradient>
  </defs>
  <line x1="14" y1="52" x2="42" y2="22" stroke="#475569" stroke-width="6" stroke-linecap="round"/>
  <!-- 方头重锤 -->
  <rect x="34" y="10" width="22" height="14" rx="3" transform="rotate(-45 45 17)" fill="url(#steelHead)" stroke="#38BDF8" stroke-width="2"/>
  <rect x="38" y="18" width="6" height="8" transform="rotate(-45 41 22)" fill="#38BDF8"/>
</svg>""",

    # 7. 材料与资源系列 (Material & Resources)
    # 原木 (Wood)
    "res_wood.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="logBark" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#92400E"/>
      <stop offset="100%" stop-color="#451A03"/>
    </linearGradient>
  </defs>
  <!-- 圆木筒体 -->
  <path d="M16 22 L44 14 Q52 14 52 24 L52 40 Q52 48 44 48 L16 48 Z" fill="url(#logBark)" stroke="#B45309" stroke-width="2"/>
  <!-- 年轮截面 -->
  <ellipse cx="20" cy="34" rx="8" ry="14" fill="#FDE68A" stroke="#B45309" stroke-width="2"/>
  <ellipse cx="20" cy="34" rx="4" ry="7" fill="none" stroke="#D97706" stroke-width="1.5"/>
</svg>""",

    # 枯枝 (Stick)
    "res_stick.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <path d="M14 50 L48 14" stroke="#B45309" stroke-width="5" stroke-linecap="round"/>
  <path d="M34 28 L44 24" stroke="#B45309" stroke-width="4" stroke-linecap="round"/>
  <path d="M26 38 L20 34" stroke="#B45309" stroke-width="3.5" stroke-linecap="round"/>
  <!-- 幼芽萌绿 (参考炼金生命意象) -->
  <circle cx="45" cy="22" r="2.5" fill="#34D399"/>
</svg>""",

    # 碎石 (Stone)
    "res_stone.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="rockGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#94A3B8"/>
      <stop offset="100%" stop-color="#334155"/>
    </linearGradient>
  </defs>
  <polygon points="12,38 22,18 44,14 54,30 48,50 24,52" fill="url(#rockGrad)" stroke="#E2E8F0" stroke-width="2"/>
  <polyline points="22,18 36,34 54,30" fill="none" stroke="#CBD5E1" stroke-width="1.5"/>
  <polyline points="36,34 24,52" fill="none" stroke="#1E293B" stroke-width="1.5"/>
</svg>""",

    # 燧石 (Flint)
    "res_flint.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="flintGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#475569"/>
      <stop offset="100%" stop-color="#090D16"/>
    </linearGradient>
  </defs>
  <polygon points="32,8 14,36 24,56 46,52 52,30" fill="url(#flintGrad)" stroke="#38BDF8" stroke-width="2"/>
  <line x1="32" y1="8" x2="34" y2="44" stroke="#38BDF8" stroke-width="1.5" opacity="0.8"/>
  <polyline points="14,36 34,44 52,30" fill="none" stroke="#94A3B8" stroke-width="1.5"/>
</svg>""",

    # 水滴 (Water)
    "res_water.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="waterGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#E0F2FE"/>
      <stop offset="40%" stop-color="#38BDF8"/>
      <stop offset="100%" stop-color="#0284C7"/>
    </linearGradient>
  </defs>
  <path d="M32 8 C32 8 14 30 14 42 A18 18 0 0 0 50 42 C50 30 32 8 32 8 Z" fill="url(#waterGrad)" stroke="#BAE6FD" stroke-width="2"/>
  <path d="M24 38 A8 8 0 0 1 30 26" fill="none" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round" opacity="0.8"/>
</svg>""",

    # 木炭 (Charcoal - 带红色炽热余烬)
    "res_charcoal.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="charGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#334155"/>
      <stop offset="100%" stop-color="#0B0F19"/>
    </linearGradient>
  </defs>
  <polygon points="16,36 26,16 48,18 52,38 42,52 22,50" fill="url(#charGrad)" stroke="#475569" stroke-width="2"/>
  <!-- 余烬裂隙赤芒 -->
  <path d="M26 32 Q34 36 40 30 T44 42" fill="none" stroke="#F97316" stroke-width="2.5"/>
  <circle cx="34" cy="36" r="2" fill="#FEF08A"/>
</svg>""",

    # 孔雀石铜矿 (Malachite - 宝石绿晶簇)
    "res_malachite.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="malaGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#6EE7B7"/>
      <stop offset="50%" stop-color="#10B981"/>
      <stop offset="100%" stop-color="#064E3B"/>
    </linearGradient>
  </defs>
  <!-- 主晶体 -->
  <polygon points="32,6 44,24 38,54 26,54 20,24" fill="url(#malaGrad)" stroke="#A7F3D0" stroke-width="1.8"/>
  <!-- 侧伴生晶簇 -->
  <polygon points="16,28 26,16 28,42 12,46" fill="url(#malaGrad)" stroke="#A7F3D0" stroke-width="1.5"/>
  <polygon points="46,26 54,34 46,50 38,42" fill="url(#malaGrad)" stroke="#A7F3D0" stroke-width="1.5"/>
  <!-- 晶体棱线反光 -->
  <line x1="32" y1="6" x2="32" y2="54" stroke="#ECFDF5" stroke-width="1.5"/>
</svg>""",

    # 矿石通用 (res_ore.svg)
    "res_ore.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="oreGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#C084FC"/>
      <stop offset="60%" stop-color="#7C3AED"/>
      <stop offset="100%" stop-color="#4C1D95"/>
    </linearGradient>
  </defs>
  <polygon points="32,6 44,24 38,54 26,54 20,24" fill="url(#oreGrad)" stroke="#E9D5FF" stroke-width="1.8"/>
  <polygon points="16,28 26,16 28,42 12,46" fill="url(#oreGrad)" stroke="#E9D5FF" stroke-width="1.5"/>
  <polygon points="46,26 54,34 46,50 38,42" fill="url(#oreGrad)" stroke="#E9D5FF" stroke-width="1.5"/>
  <line x1="32" y1="6" x2="32" y2="54" stroke="#F5F3FF" stroke-width="1.5"/>
</svg>""",

    # 赤铁矿 (Hematite - 深红玄铁晶体)
    "res_hematite.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="hemGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F87171"/>
      <stop offset="50%" stop-color="#DC2626"/>
      <stop offset="100%" stop-color="#450A0A"/>
    </linearGradient>
  </defs>
  <polygon points="32,8 52,22 46,52 20,54 12,28" fill="url(#hemGrad)" stroke="#FECACA" stroke-width="2"/>
  <polyline points="32,8 36,36 46,52" fill="none" stroke="#FCA5A5" stroke-width="1.5"/>
  <polyline points="12,28 36,36 20,54" fill="none" stroke="#7F1D1D" stroke-width="1.5"/>
</svg>""",

    # 金属铜 (Copper - 纯铜元素卡片/金属锭，参考图中的 Fe/Au 卡片风格)
    "res_copper.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="cuBadge" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F97316"/>
      <stop offset="100%" stop-color="#7C2D12"/>
    </linearGradient>
  </defs>
  <!-- 元素小方卡 (参考图中的 Au 79 / Fe 26 风格卡片) -->
  <rect x="8" y="8" width="48" height="48" rx="8" fill="url(#cuBadge)" stroke="#FDBA74" stroke-width="2.5"/>
  <text x="44" y="22" font-family="sans-serif" font-size="10" font-weight="bold" fill="#FED7AA" text-anchor="middle">29</text>
  <text x="32" y="40" font-family="sans-serif" font-size="20" font-weight="900" fill="#FFFFFF" text-anchor="middle">Cu</text>
  <text x="32" y="50" font-family="sans-serif" font-size="8" fill="#FDBA74" text-anchor="middle">63.54</text>
</svg>""",

    # 金属铁 (Iron - 纯铁元素卡片，参考图中的 Fe 26)
    "res_iron.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="feBadge" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#EF4444"/>
      <stop offset="100%" stop-color="#7F1D1D"/>
    </linearGradient>
  </defs>
  <rect x="8" y="8" width="48" height="48" rx="8" fill="url(#feBadge)" stroke="#FCA5A5" stroke-width="2.5"/>
  <text x="44" y="22" font-family="sans-serif" font-size="10" font-weight="bold" fill="#FECACA" text-anchor="middle">26</text>
  <text x="32" y="40" font-family="sans-serif" font-size="20" font-weight="900" fill="#FFFFFF" text-anchor="middle">Fe</text>
  <text x="32" y="50" font-family="sans-serif" font-size="8" fill="#FECACA" text-anchor="middle">55.84</text>
</svg>""",

    # 石盐 (Halite - 立方盐晶与微光)
    "res_salt.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="saltGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#93C5FD"/>
    </linearGradient>
  </defs>
  <polygon points="32,10 50,20 50,42 32,52 14,42 14,20" fill="url(#saltGrad)" stroke="#BFDBFE" stroke-width="2"/>
  <polyline points="14,20 32,30 50,20" fill="none" stroke="#E2E8F0" stroke-width="2"/>
  <line x1="32" y1="30" x2="32" y2="52" stroke="#60A5FA" stroke-width="2"/>
  <!-- 盐晶微芒 -->
  <polygon points="20,12 22,8 26,10 22,14" fill="#38BDF8"/>
</svg>""",

    # 硫磺 (Sulfur - 鲜黄硫晶)
    "res_sulfur.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="sulfurGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FEF08A"/>
      <stop offset="60%" stop-color="#EAB308"/>
      <stop offset="100%" stop-color="#854D0E"/>
    </linearGradient>
  </defs>
  <polygon points="32,8 46,20 42,48 22,50 16,24" fill="url(#sulfurGrad)" stroke="#FEF08A" stroke-width="2"/>
  <polygon points="42,22 56,32 50,46 38,40" fill="url(#sulfurGrad)" stroke="#FEF08A" stroke-width="1.5"/>
  <line x1="32" y1="8" x2="34" y2="48" stroke="#FEF9C3" stroke-width="1.8"/>
</svg>""",

    # 燃料火焰 (Fuel Fire)
    "fuel_fire.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <radialGradient id="fireOuter" cx="50%" cy="80%" r="70%">
      <stop offset="0%" stop-color="#FEF08A"/>
      <stop offset="40%" stop-color="#F97316"/>
      <stop offset="100%" stop-color="#B91C1C"/>
    </radialGradient>
  </defs>
  <path d="M32 6 C32 6 20 22 20 38 A16 16 0 0 0 52 38 C52 24 38 16 38 16 C38 16 42 26 36 28 C30 30 32 6 32 6 Z" 
        fill="url(#fireOuter)" stroke="#FDE047" stroke-width="2"/>
  <path d="M32 48 A6 8 0 0 0 32 32 A6 8 0 0 0 32 48 Z" fill="#FEF08A"/>
</svg>""",

    # 工业蓝图芯片 (Blueprint)
    "blueprint.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="bpGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0284C7"/>
      <stop offset="100%" stop-color="#0F172A"/>
    </linearGradient>
  </defs>
  <rect x="12" y="8" width="40" height="48" rx="6" fill="url(#bpGrad)" stroke="#38BDF8" stroke-width="2"/>
  <!-- 炼金电路芯片纹路 -->
  <line x1="20" y1="18" x2="44" y2="18" stroke="#7DD3FC" stroke-width="2"/>
  <line x1="20" y1="28" x2="36" y2="28" stroke="#7DD3FC" stroke-width="2"/>
  <circle cx="42" cy="28" r="2.5" fill="#FBBF24"/>
  <polyline points="20,38 28,38 34,46 44,46" fill="none" stroke="#A855F7" stroke-width="2"/>
</svg>""",

    # 元素周期表墙 (Periodic Table Wall)
    "periodic_table.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect x="8" y="8" width="48" height="48" rx="8" fill="#161936" stroke="#818CF8" stroke-width="2"/>
  <!-- 网格元素方块 -->
  <rect x="14" y="14" width="10" height="10" rx="2" fill="#38BDF8"/>
  <rect x="40" y="14" width="10" height="10" rx="2" fill="#A855F7"/>
  <rect x="14" y="27" width="10" height="10" rx="2" fill="#F59E0B"/>
  <rect x="27" y="27" width="10" height="10" rx="2" fill="#10B981"/>
  <rect x="40" y="27" width="10" height="10" rx="2" fill="#EF4444"/>
  <rect x="14" y="40" width="10" height="10" rx="2" fill="#E2E8F0"/>
  <rect x="27" y="40" width="10" height="10" rx="2" fill="#E2E8F0"/>
  <rect x="40" y="40" width="10" height="10" rx="2" fill="#E2E8F0"/>
</svg>""",

    # 时代徽标 (Era)
    "era.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="eraGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FBBF24"/>
      <stop offset="100%" stop-color="#D97706"/>
    </linearGradient>
  </defs>
  <!-- 帕特农神庙/纪元圣殿 -->
  <polygon points="32,10 12,24 52,24" fill="url(#eraGrad)" stroke="#FDE68A" stroke-width="2"/>
  <rect x="16" y="24" width="32" height="4" fill="#FDE68A"/>
  <!-- 四根多立克立柱 -->
  <line x1="18" y1="28" x2="18" y2="48" stroke="#FDE68A" stroke-width="4"/>
  <line x1="27" y1="28" x2="27" y2="48" stroke="#FDE68A" stroke-width="4"/>
  <line x1="37" y1="28" x2="37" y2="48" stroke="#FDE68A" stroke-width="4"/>
  <line x1="46" y1="28" x2="46" y2="48" stroke="#FDE68A" stroke-width="4"/>
  <rect x="12" y="48" width="40" height="6" rx="2" fill="url(#eraGrad)" stroke="#FDE68A" stroke-width="1.5"/>
</svg>""",

    # 系统菜单按钮 (Menu)
    "menu.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect x="10" y="10" width="44" height="44" rx="8" fill="#12142B" stroke="#64748B" stroke-width="2"/>
  <line x1="20" y1="24" x2="44" y2="24" stroke="#F1F5F9" stroke-width="3" stroke-linecap="round"/>
  <line x1="20" y1="32" x2="44" y2="32" stroke="#38BDF8" stroke-width="3" stroke-linecap="round"/>
  <line x1="20" y1="40" x2="44" y2="40" stroke="#F1F5F9" stroke-width="3" stroke-linecap="round"/>
</svg>"""
}

for name, content in icons.items():
    file_path = os.path.join(ICONS_DIR, name)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Generated: {name}")

print(f"Successfully generated {len(icons)} modern vector icons matching reference style!")
