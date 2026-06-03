# Minecraft 1.16.5 Forge Pack Mod List

Generated: 2026-06-03T18:26:08.2400633Z

## Release

- Minecraft: 1.16.5
- Forge: 36.2.42
- Asset archive: `pack-assets-60d911738ade.zip`
- Asset SHA-256: `60d911738ade488be2a5348998ecd8fea5a23afce0dc7c90436fa8091345613e`
- Asset URL: <https://github.com/Chicken3veryDay/minecraft-1.16.5-forge-pack/releases/download/v2026.06.03/pack-assets-60d911738ade.zip>
- Minimal installer: `minimal-pack-5db74f0aec37.zip`
- Minimal installer SHA-256: `5db74f0aec3797aa67472f5b713e7e5a384c85ee7b8a3d80e336fd974a36e6f2`
- Crafting fix: Polymorph remains removed from client and server because it changes recipe selection/workbench result synchronization and matched the earlier ghost/empty crafting-result symptom.
- Previous-version restore: Combined server-join fix: MyServerIsCompatible was removed from Client because it only hides Forge incompatible-server warnings. The server-required utility/gameplay jars that were previously server-only are now also included in Client: AI Improvements, Chunk Sending, Chunky, Connectivity, FastFurnace, FastSuite, FastWorkbench, Let Me Despawn, SmoothChunk, Spark, and Tree Harvester. Mowzie's Mobs was updated from 1.5.25 to 1.5.27 on Client and Server to fix the GeckoLib 3.0.106 startup crash: NoSuchFieldError children.
- Validation: Dependency audit reads each jar META-INF/mods.toml and manifest Implementation-Version. Latest audit: no missing required dependencies, no incompatible required dependency ranges, no duplicate mod IDs, no Polymorph jar present, no MyServerIsCompatible jar present in Client, and Mowzie's Mobs 1.5.27 present on both sides.

## Client Mods (158)

| File | Size | SHA-256 |
|---|---:|---|
| `abnormals_core-1.16.5-3.3.0.jar` | 975289 | `81837680e01bcf1deddb062eeea84b4f2ae67d9a69f79f48993d589d64eef2f0` |
| `accelerated-decay-forge-69.0.0.jar` | 11840 | `fe6aba0bb2e4785be15210f433c8dc653ae3130c8b9d7a2b88ca47e6914bf4ba` |
| `AdLods-1.16.5-4.1.10.0-build.0337.jar` | 107472 | `9ebd9629659f40a29a5fca84e675f029fe7576ee43768d0193a431bc38d4f2f5` |
| `AI-Improvements-1.16.5-0.5.0.jar` | 28376 | `42994ada8ac233fde3a05d9be170c3d25d671f68339c798f1e7d1dab320fbdc4` |
| `alexsmobs-1.12.1.jar` | 18135643 | `e5a29a46d1a83cfb705188168c38fbe65f0a1ac8c6126dc0f5f881ab3c1c6712` |
| `alltheores-1.3.6-1.16.5-36.1.0.jar` | 484268 | `79b137888a5a999804d55e13a3fcad1c32798e773051227e878303ad78461447` |
| `AmbientSounds_v3.1.11_mc1.16.5.jar` | 76505097 | `8943f381c944e716e6e6bade1df531373b05315e2a80c59ce49e4c1ab635487e` |
| `AoA3-1.16.5-3.6.11.jar` | 137118802 | `34bd44a5118f85a7af5ff61f2186adc0e022e9ed808ced37ff648b0169b6f313` |
| `Apotheosis-1.16.5-4.8.9A0.jar` | 1169760 | `bf0f3532db5811841db2fafe060a47baae875a2d1282e66e128972e4ad4d273b` |
| `appleskin-forge-mc1.16.x-2.5.1.jar` | 47721 | `6dd1d2ef1daa6871b79f5ca2ac1e757ec731f94958f12397b43670b188091b62` |
| `appliedenergistics2-8.4.7.jar` | 4820914 | `794cce73410f689e9b55f70c76d624c3e7bcb3dec843a0e9d5d0e0603f93a09e` |
| `Aquaculture-1.16.5-2.1.23.jar` | 551038 | `8530c90cea42f10fe0e0706e7ab73fe65e48d4cce8e684c3455c338196150345` |
| `aquamirae-5.4.API11.jar` | 17219961 | `cb33bc9d7abbbee4c46703a944fdd2a65926b031ce596b71773db6bf89d72aa2` |
| `architectury-1.32.68.jar` | 551889 | `e240c66919e3920d864de30138f0790072fdd72e3a27b69ba2865ab92153fba3` |
| `Artifacts-1.16.5-2.10.6.jar` | 470061 | `5563c9b47265919361ec9323c5a7a8362429747cdc3449e20023fe1bc39d2436` |
| `Atlas-Lib-1.16.5-1.1.3c.jar` | 50209 | `dd03d054f49c055beca5b327cde795ff4c944b3ccfb88cbe299573e440c50c34` |
| `AttributeFix-1.16.5-10.1.4.jar` | 9569 | `f7b42c13914392a6d5ab114e3241d094aada6f9241a2c401e4c185410aa25b8c` |
| `Atum-1.16.5-2.2.12.jar` | 4590649 | `b06ef313f1759c04a28587ceecf8c6d838ac079be55b1a89ad9aa8a58907079f` |
| `AutoRegLib-1.6-49.jar` | 57279 | `2760b765dccf1fad36e74f747ee9b1a2923e2d09eb281c72258c15bb4ed427d5` |
| `BetterCaves-Forge-1.16.4-1.1.2.jar` | 1402482 | `5182379427440bb4198790856c01f28c085365cc37ad3a05a9cd82dfdf068454` |
| `BetterCompatibilityChecker-1.0.7-build.22+mc1.16.5.jar` | 15695 | `b879e60507bd17741b8af60f00d4233b225d702e618f77ef0be9d7fcb70d8bbd` |
| `BetterDungeons-1.16.4-1.2.1.jar` | 510439 | `3cf47e1e09321c8ab7d0b2d98f4edbec865f40db14d57bbaee0cf7f1966fc7f3` |
| `betterendforge-1.16.5-2.5.jar` | 93330331 | `87c392eaf43706d579def4c973a3ccf970bbb6895cc57b72b8414eae3b9984a9` |
| `betterfpsdist-1.2.jar` | 14478 | `02af47e907b36f802818e62472811ea3b668da9bb23645120ca090707376f529` |
| `BetterMineshafts-Forge-1.16.4-2.0.4.jar` | 289307 | `19b9b7f87da2bb76574e9f3e3d18d445189a4627cfd0d8188ae88eb681b578b8` |
| `betternether_reforged-1.2.jar` | 22443866 | `a7d418801f69a513316ddeaf7b993e3f96899da4f408a90082e0fbace86bca95` |
| `BetterStrongholds-1.16.4-1.2.1.jar` | 541396 | `ca03a43d0d66b2923b830c4cac03cc1e207eba7dbf8bddb3f33f93e710bb3a1b` |
| `BetterThanMending-1.6.0.jar` | 5156 | `328981d3c31e28ff6051d622009444e80dc1f35a9454f7a1465d745f3250bc75` |
| `BiomesOPlenty-1.16.5-13.1.0.488-universal.jar` | 3651046 | `2806139055dc330a1e8f7a4324a68b6305a9eb67cc132ef09b81bdec5e89d9bb` |
| `blue_skies-1.16.5-1.1.3.jar` | 97691834 | `24da6b5f814524d65092f30100f8c863e06560e0ac55402cbf696790a218c57e` |
| `Bookshelf-Forge-1.16.5-10.4.33.jar` | 317032 | `a5753a80a09db5423feae7f7786dec30e844cee6318d1d8546e8512f067c15ad` |
| `born_in_chaos_1.16_1.3.jar` | 4346948 | `6efcc1109c3b48f36633805ac203768e2a77c921fbb2aaf3e5afd1fcd1cba70a` |
| `bountifulbaubles-1.16.5-0.1.0-forge.jar` | 340889 | `75c6c24057e6907e11f3ce1af76bc34a2c584201917078385d3c922e19f8b213` |
| `bygonenether-1.3.2-1.16.5.jar` | 7682525 | `e935fbad46cee58fb71d8a14110a16faa1978f6f058b7a69dae1f5f75a9b1f79` |
| `caelus-forge-1.16.5-2.1.3.2.jar` | 41824 | `f8536bca6f45ab90388fe49b37d8612f2d27d3213d1df6d0309830cb5f99da48` |
| `carryon-1.16.5-1.15.6.24.jar` | 321769 | `0e294b86d831f5afa162c1d14cd1832541768341f92493ded9e7eb0377d06d2e` |
| `catalogue-1.6.1-1.16.5.jar` | 97637 | `89abfb4277aa3dee8730df138ebf393aeae479f711ebbea8ede5312b48e3214b` |
| `champions-forge-1.16.5-2.0.1.16.jar` | 222925 | `3998f26510dc492304111e4add8dd7cdc58d69dba6c47ef0ed76f86d25d18cbf` |
| `chunksending-1.16.5-2.5.jar` | 13027 | `fbc4293c00b33aba3c292521058b9880eeeeb652893e549727927a3d08683b0c` |
| `Chunky-1.2.123.jar` | 210906 | `ea25f65d7c8942442b8feff17a1c86a5e5f6706bf95ff17ee7711ea193721e37` |
| `citadel-1.8.1-1.16.5.jar` | 482439 | `4c78a18f309aa9895ff6ef70fc3140c436c729fa84c832770ec30970daaab88a` |
| `Clumps-6.0.0.28.jar` | 18397 | `f69abc1d44277b495004fd6d67d0f95f2574581bb26e55543f2dcd2153cd92d0` |
| `collective-1.16.5-5.49.jar` | 189273 | `eea0121bbad3eefbbe0283d18758decba872e1d2f1fef8352a24f0a9f9d586d7` |
| `configured-1.5.4-1.16.5.jar` | 131868 | `6c356a0422a650304b97a6ddadd0ccfa036031f2cd23d067e9ceba5c56b3e0d5` |
| `connectivity-2.3-1.16.5.jar` | 52995 | `07f1a43915116527e488bad92609516f1c241a64d8c9c887e6a9f522f8accfe3` |
| `Controlling-7.0.0.31.jar` | 53318 | `9ee5e46e08609bae46d344d736aaf562a498133e6919164649256cbdba219fbc` |
| `coroutil-forge-1.16.5-1.3.6.jar` | 37129 | `cd9a94de2ccffa29fa18466665bd980abf021acb140632e20d7047165f047382` |
| `corpse-1.16.5-1.0.6.jar` | 203988 | `c3b1e2ac93165045f7eb88871e06d5269ee4ca0bf41a46bb86f62075c9f778ef` |
| `CrashAssistant-forge-1.16.1-1.16.5-1.11.9.jar` | 3417705 | `0dfb7815f059b0cdcdb7daf5a9441fc1de37a33b5ad646a47ce0f18c7f2f6601` |
| `Craziniess Awakened.jar` | 226446 | `0ceca339e720cc9bbd43fc23bc89682f57e22624060930204c854b8b3ef53d31` |
| `CreativeCore_v2.2.1_mc1.16.5.jar` | 631207 | `33722a10a6083999f82f46c76fd9e7d38577c1b4f5d46296234664d9b0bedcbd` |
| `curios-forge-1.16.5-4.1.0.0.jar` | 291897 | `952a276d7a2c8fdef29794711b73bfa308e7fd96ec1e2d51750523456d9f892b` |
| `curiouselytra-forge-1.16.5-4.0.2.5.jar` | 35474 | `28cc8251e25a9aeec023f1e2783264bd780fb765464b9f58732dc815e4d2436a` |
| `CustomNPCs-1.16.5-GBFix-Unofficial-20250630.jar` | 12686594 | `962e276188e89d75fd9a20d46f10e61ba1a455143796cda1d8af409473de5a8c` |
| `DivineRPG-1.8.27.jar` | 18216367 | `dec4318b729f77dc5015b2c147fd85a53208b364b4d80507e9056618069f5595` |
| `dragonfight-1.8.jar` | 29608 | `1d02462824141cb11b6fbb79117cb9b922df5ed12740e92e10b9d446ca4d1282` |
| `DungeonCrawl-1.16.5-2.3.12.jar` | 797023 | `1b3966775743ed8a3389dbe59027b1fad98f70e6da93c278530e5aec3575b0cf` |
| `dungeons_enhanced-1.16.5-1.9.2.jar` | 1071358 | `44c998f63aabfa0f17b498d9de449eb08e9fdf18e626fc122e243853988315c9` |
| `dungeons_gear-1.16.5-3.2.7.jar` | 3072823 | `75841c6284daca5c95f7fab1a30f95b6a0f556d66e0135d0c3e158a78d456a61` |
| `dungeons_libraries-1.16.5-1.0.6.jar` | 647661 | `9b99900e4f0d7e9e5952f6944c17cbfb8ccfb03bfced9d161f0d47584637a78d` |
| `dungeons_mobs-1.16.5-2.2.3.jar` | 12420294 | `0437a6732963a7399240b9112cadce6a72d6b872989774ec7ada76179c338fdc` |
| `DungeonsArise-1.16.5-2.1.49-beta.jar` | 5544981 | `2d60816a6ebdbc031e06b06b548d9c94836af3d3b4c6b81870aa1221054a666a` |
| `embeddium-0.3.18+mc1.16.5.jar` | 806163 | `5b5e25b96bd8acede00882f2dc32dccf9e21841778da8bf88d3e3955440a3a52` |
| `EnchantmentDescriptions-1.16.5-7.1.27.jar` | 58127 | `bea1a374ab716e1159029dfa1ff1c8d1fde0524b71751938cdbd8779ae71e5bf` |
| `endergetic-1.16.5-3.0.2.jar` | 11036888 | `4f1e17ee38cb18a663e03e7e10cdddae836c5850bbbde66ea054dcefa042a22f` |
| `endrem-5.0.3-R-1.16.X.jar` | 1644035 | `bf782c56f8edb4d0ea43b9ec98ce7e7b2b398d1779a9418fa670c7b0602f6b18` |
| `EnigmaticLegacy-2.11.12.jar` | 1516976 | `6d831bd40f99b2112f42d168355da611389dfe48a1098c12f2302423b64d53e7` |
| `entityculling-forge-mc1.16.5-1.5.2.jar` | 46532 | `452d9fe997d8514abd28f3b06245a388385cd8b9baf98cce3c76c2915cd7db91` |
| `expandability-2.0.1-forge.jar` | 43358 | `0959cffb3a545730e6b2e1377bb89b59ff96e7f9142f54cc8035ab4fa2fc76e1` |
| `farsight-1.7.jar` | 10183 | `6aabe8b3689eaf73be45728966459db110e0351427d802abfa6256e7a5557715` |
| `fastboot-1.16.x-1.1.jar` | 24684 | `db208c8df5b6aed46fb4e30af19766ef568aef50bce664329392ffb1cb9cf3f4` |
| `FastFurnace-1.16.5-4.5.0.jar` | 5907 | `fc384eeb166b8610e2f21b4f14e3341285744370b56fbb52d91bd4ee4bb8f106` |
| `fast-ip-ping-v1.0.11-mc1.16.5-forge.jar` | 10556 | `3882b4680b20121e53f2fa1f51922387ad3cab3b12b39a8a265f8c496cfacde4` |
| `FastSuite-1.16.4-1.1.1.jar` | 10829 | `3195239313100586bfa2f4dd02c5da0e20d7cfd5f7c00b8147efc2842f235be6` |
| `FastWorkbench-1.16.5-4.6.2.jar` | 22470 | `36f00c55c8414467a40f784d15a4f6a24406a8847703cbbd73033df1f7c18526` |
| `ferritecore-2.1.1-forge.jar` | 108557 | `9aec89734cdf8cb0ee31649e3f6aab9c04f2621eddecff8e31ccdfe18cf8e87a` |
| `ForgeEndertech-1.16.5-7.3.0.0-build.0330.jar` | 542410 | `6435fbe173052e38808a60a5eacf1f8188a0fb3befba9059ff7bf32b86fdc311` |
| `FpsReducer-forge-1.24-mc1.16.5.jar` | 95076 | `7455e9c992270b0302190ea288b7f3fe3791106345ef4095978d081d78f5756f` |
| `ftb-library-forge-1605.3.4-build.90.jar` | 585125 | `f2bd3aa612d959eb10e7cb9b212c11cd9b6625fc9172ecbc24c9b804f0fe9e8b` |
| `ftb-ultimine-forge-1605.3.1-build.45.jar` | 78597 | `3a045ebcdf4ce291022497b1889054d0dd6137075dffc3a3abfc3682fdcf9bee` |
| `GatewaysToEternity-1.16.5-1.0.2.jar` | 564724 | `7cf60c0e09ebc4d5e9929c426e4c202dfd857c93f37241d31d65e434c27ae41f` |
| `geckolib-forge-1.16.5-3.0.106.jar` | 3559283 | `e130cde6859858ac2a5f8d641794d97d85400c8925c3b46fb19e1a2ea286a6ca` |
| `goblintraders-1.7.3-1.16.5.jar` | 428711 | `e2c1168ccd3f072257825f4a61e6175c40a3cf59dc124f9d54b59361fb20616b` |
| `guardvillagers-1.16.5.1.2.4.jar` | 188171 | `7b7764c511271db4cc5806768ca1d2c68522cae7ba415d6249d1756915a5c4ef` |
| `Hats-1.16.5-10.3.4.jar` | 1544164 | `f85f3af9222a2752f5620e5c1c225f4a0af2e610b96180c821770f0723194617` |
| `iceandfire-2.1.12-1.16.5-patch-1.jar` | 21463531 | `29e66bd0199169649f6de4e4b0ef00a67555eb348f10b8d01794c20d67f128c8` |
| `Iceberg-1.16.5-1.0.45.jar` | 61577 | `bec3ebbd6eead24282b075d01b4f48d3e0c2d33ad5be45e0a3270c368ed49d43` |
| `iChunUtil-1.16.5-10.7.0.jar` | 597557 | `45726157333a986d9123958ede53f09b7da3f20e88b496f715bbf5e7a4162b8b` |
| `infernal-expansion-1.16.5-2.5.0.jar` | 14629220 | `df2e79d4e019e80d2ea593a17c309237ac80481ed202f4d4cb7ae1b3c79ac364` |
| `InsaneLib-1.4.2-mc1.16.5.jar` | 45677 | `7bef0a474d0e520e0bb00488ed3575c96657e1e24941eb419b4a10a48a1b6b5c` |
| `inventorysorter-1.16.1-18.1.0.jar` | 49966 | `afb49ff93fdd9590a3d39a04df4fabef32afce0e331fe40339fe6b10e3091d6e` |
| `ironfurnaces-1.16.5-2.7.7.jar` | 493742 | `1203c7ddd5e6d36a7db144f8f425f3d7b23acd89452208fa7d0da5c8c298bba6` |
| `itemcollectors-1.1.12-forge-mc1.16.jar` | 99093 | `d5622aaf09238d00c78ae8a44e4fa5bdfa96232d82048a18582c917deae0388b` |
| `Jade-1.16.4-2.8.3.jar` | 260212 | `23d729281f30970ad70447aed4789dbf9730f577faec6f82f007cba7e85b28f3` |
| `jei-1.16.5-7.8.0.1013.jar` | 816694 | `09c42a9d516ed3c8bd649ddd9cde5de05989a8205f5b2fcbf2d5c47c2f4637cd` |
| `journeymap-1.16.5-5.8.6.jar` | 6694200 | `28a42489724b0a70c1d75f84da1ffc922c893d2a76a7cbeb24ea24f47016cbf5` |
| `JustEnoughResources-1.16.5-0.12.2.216.jar` | 236423 | `022c883b9deeb5e11cd34e8e89181f70ff343285624310e16dc52ea042cd5933` |
| `L_Enders Cataclysm-0.48 Changed Theme -1.16.5.jar` | 12700153 | `617c92ad1a3b970aa27201f8a26f3c356dc16571a45a64f8fb3ec89cfd01c6fc` |
| `LegendaryTooltips-1.16.5-1.3.1.jar` | 47620 | `aa5cb4542850e23184729859398ea034cba292b1d62401b390fa751671bf34b5` |
| `letmedespawn-forge-1.3.2b.jar` | 85166 | `c7f8d88fa26b70e70bf012f3438d7e23b56050a73d34d43abdbd6a50c372fed3` |
| `LightAura-4.4.0.jar` | 18705 | `358ff6f2f64219561f5fd57e5025f66dd9f1ff02231f64195ad2c28fdbe7df42` |
| `lootr-1.16.5-0.2.19.52.jar` | 377041 | `14e9069f2a053d20436f3dcf445a69d94ffc59e6d5aa1eed4c6e417469db9d10` |
| `lucky-block-forge-1.16.5-6.0.jar` | 1921940 | `f842dec8095394aed3332bfd773f26c5f683bf339473279449d3fcf009395016` |
| `MaxHealthFix-Forge-1.16.5-1.0.5.jar` | 6725 | `bab21006279f6d6d018764a511fe0e06b9437cfe5d8a1ded61d8d44a8601b00b` |
| `meetyourfight-1.16.5-1.2.0.jar` | 2003393 | `f6a71bd6a2206e8b90068dba66921da1817438622db8456a9c7831e9d42be3ef` |
| `mobile-trashcan-1.0.0-backport-1.16.5.jar` | 67567 | `06d6344a874363acd0f404b3e7c93fa1903e5d82edb405c04ebae1339d5d10d2` |
| `MobsPropertiesRandomness-3.3.0-mc1.16.5.jar` | 110479 | `2cf244eb10fa3c9d90ddda0553905aef4c923ad0527204d1173f00496002f78e` |
| `modernfix-forge-5.18.0+mc1.16.5.jar` | 867079 | `17ff7a1096275e1c6706a8f65d3f903b5eccb4a979f4aeb5b4302b3966c5bde8` |
| `Morph-1.16.5-10.2.1.jar` | 1277555 | `f5a150ae5952c8e12829c0c1375d62ef337d325d87dc13aa1885b90bef70b0da` |
| `MouseTweaks-2.14-mc1.16.2.jar` | 58249 | `9d7e1aaee9f814c26d896e084e6e86930ab99e19fe547a1d350a6e25e4267092` |
| `mowziesmobs-1.5.27.jar` | 13557419 | `1c35253f5c3f85591ab5ccdffdef9777433ae2c3eb54fbae1bdf77146a6681d3` |
| `MutantBeasts-1.16.4-1.1.3.jar` | 1289476 | `1d008fed88518398ed960d4e291ead910fd23e9e1d854436760716ab74c2af00` |
| `NaturesCompass-1.16.5-1.9.1-forge.jar` | 203573 | `f5f94447b6fde00eb450ba18236ce77a2f3f05998cf250841813afdf4b3303cd` |
| `obscure_api-11.jar` | 859106 | `1c2d5c8976b7d4b4e298b3f30de78bc53eb3c1d288ec8c67e3af9a224ba88b07` |
| `oculus-mc1.16.5-1.4.8.jar` | 3133901 | `2d1cf9d4c42f03acfbc941e4c27751d876fb2e7867e39c82e8b9f6fb7c74bb2f` |
| `OuterEnd-0.2.14.jar` | 57328296 | `ae0a9d00fb5f20bd867c758175ac0fd6ed35191469904da78c1eee095dc55ad3` |
| `pandorasbox-2.2.6-1.16.5.jar` | 375701 | `91c6a1f560dc06380a68c3c7316db30ad8eeb3c0801b857f977d7446d218a082` |
| `Patchouli-1.16.4-53.3.jar` | 593352 | `691b66041157601d1b89e7ff66d1d7ab08b97a3f1163caf600bfaceef5a1cc88` |
| `Pehkui-3.8.2+1.16.5-forge.jar` | 674598 | `9f9aa89ddbc4a80b0c508c55aa25a3120f769e8aefacc68e22c06293aeb557fe` |
| `PickUpNotifier-v1.2-1.16.3.jar` | 42604 | `048cebf7c8ff0ec94ca30cafb4e22e2839e419e69082cbad2d5cd2de247aac13` |
| `Placebo-1.16.5-4.7.1.jar` | 174158 | `eef4835343a46cc3c45776d905b52aced3f3b233d00a04ba646aaa9c6111b789` |
| `Prism-1.16.5-1.0.1.jar` | 51909 | `8f5d4cefa734d972b8142e92bbbabc20967ef7a5f93f00071c8036d38ae3f402` |
| `ProjectE-1.16.5-PE1.0.2.jar` | 2099991 | `626f0d0e8b9e044e4d6742c61925389babe4efdc42aaaceceb7b826418b62b11` |
| `puffish_skills-0.5.0-1.16.5-forge.jar` | 300512 | `282437fa05245b91b4ec7184c6bb283b1450682d4b52d4046dd8703255cde4c7` |
| `Quark-r2.4-322.jar` | 8796901 | `dcbccfaf08982ff7d8e11c6c4b54de75ad161317d5b69bcefe2e3c009040db25` |
| `realmrpg_fallen_adventurers_0.2.0_forge_1.16.5.jar` | 332998 | `6db2b382a1f35f657b5496ec66887f17efbc7ed583251003d184db1c29f8b234` |
| `relics-1.16.5-0.3.4.4.jar` | 1118083 | `b70dcf699d2d4cf8a8235a824c772612b880d6f76d6fc42c83b67e21bcc2c6be` |
| `remodifier-1.16.5-2.2.3.jar` | 91799 | `ab8629de02bafde2bb8e96ff5cc1c19cb13e48bf43189b857c027b358747d809` |
| `repurposed_structures_forge-3.4.7+1.16.5.jar` | 5576490 | `b1dda698ebe52b2508c306eae73d51951fe7e9ffceea42b9fc966500eb5ecd35` |
| `RoadRunner-mc1.16.5-1.5.2.jar` | 393531 | `7312852ccf34b21b8dbeeb077796e082a141747082e686bba8882ae68cd9907f` |
| `rubidium-extra-0.4.18+mc1.16.5-build.107.jar` | 313734 | `6acba53a8c411fcd92646be531b1d7d0d069e8e6af4768153370a47540b4fe85` |
| `savageandravage-1.16.5-3.2.0.jar` | 1271118 | `4bb51b03efb4efd0fdb6d750789d13f87522e4ab4e2c23f53ebbb842b2bc4151` |
| `ScalingHealth-1.16.5-4.1.5+11.jar` | 513375 | `f0d7538b7dbdbce23d369cec592fe7ad2c60951aa38b73ef1b5ec8f2d246f04c` |
| `silent-gear-1.16.5-2.6.30.jar` | 2583204 | `cdcdfd9d45d2a18a5a35e04f9f812bbde9a4ad373445aac644d623f1c3dfc17c` |
| `silent-lib-1.16.3-4.9.6.jar` | 247616 | `ccd8757d3a8b5447bb4192c1966099cd3671b2f7e49fb0d889f32359ad2d2d45` |
| `smarterfarmers-1.16.5-1.2.1.jar` | 33716 | `405f87a08ea15ed6bc4d1c57dc8d4d6a5b6b7898a51a9b30a88fd31ebdd6e34a` |
| `smoothchunk1.16.5-2.0.jar` | 14157 | `e7ab1d4fd31ee8e8be75a711df7b403d54a86514432302c8ad79a87851a2bc26` |
| `spark-1.9.1-forge.jar` | 3157081 | `e0e10f3ba3c4169d4fe1408f4f9b081bb1f36e4cdf3777a26beab816057817e3` |
| `SpartanWeaponry-1.16.5-2.2.2.jar` | 1660410 | `7c956831c3a280b04b6227b05178b82429623ffed539f919a4e90c65763a8334` |
| `SpawnerFix-1.16.2-1.0.0.3.jar` | 63376 | `525aa0af91fe30af5a3b265837803ab08024b06948ea5168d7b0e434d4981c47` |
| `stalwart-dungeons-1.16.5-1.1.7.jar` | 1542647 | `0502fdf83f471c520ab0894f3e50afd5f7067c09fd96dccd44f6646133287e44` |
| `structure_gel-1.16.5-1.7.8.jar` | 261390 | `f35cefe2536ec37604c46a9e745ad5c8255eef37be4d88992dbd365a484880a8` |
| `supermartijn642configlib-1.1.6-forge-mc1.16.jar` | 205206 | `8a29776877e176b127fad0f3a9e8b193150b2a478b9f9629bdd3c4878df416ed` |
| `supermartijn642corelib-1.1.21-forge-mc1.16.jar` | 541853 | `5a180e7d63d3b916132bebd2e673779c5bf4b24a1ab6b9adf0d3ec7a3d17ca20` |
| `takesapillage-1.0.3-1.16.5.jar` | 3764552 | `d9e45dccaf587d2f50df5104cffecbc429dd57b63bd29174e0b46bc90f776aaa` |
| `Terraria Trinkets - 1.0.1 [1.16.5].jar` | 93141 | `830cb896b73f3d68594ff63e0c52d2c525c1a8d2d81dd67c23ba19988073f3bb` |
| `TextruesRubidiumOptions-1.0.8-mc1.16.5.jar` | 211610 | `cd42f361e6d7b48b6db002e14c9c1fd3e6cf71a3e0097afc4613d798a7e16043` |
| `The_Undergarden-1.16.5-0.5.5.jar` | 63449848 | `a4ba8e7d844b80c1417d2da4579226de3a4bc77a4723aea1e08e2d7c803ade1d` |
| `TheAbyss2 2.2.3-4 1.16.5.jar` | 59405125 | `ffc1c7bd80251a3a5de593a8624eda85e6f414f98855177181319e35a88662d1` |
| `The-Hordes-1.16.5-1.1.5c.jar` | 198825 | `ff47da6155dd21faa72bb934c69cabaa6499894cf99f2d3cdad30ddb490ee250` |
| `towers_of_the_wild-1.16.3-2.1.0.1.jar` | 157147 | `98436d28cf075f48fc8998fc2039df059dc5bdfae128a3cecda705fb65e8455a` |
| `treeharvester_1.16.5-5.9.jar` | 22982 | `5d2262b4703bb2fbfaa829dd5bfa61aef080f3366b5316bef864e56c42d2081e` |
| `twilightforest-1.16.5-4.0.870-universal.jar` | 31748538 | `85c53f5332d54ff2890083764db8a61cb5c507638959a17a4769d73ba19006ad` |
| `upgrade_aquatic-1.16.5-3.1.2.jar` | 3682686 | `b14d6f3d8a1ba8a820a3d11e7cfe2d7b65ec84cb2b26f7859d76bab5d473d845` |
| `watut-forge-1.16.5-1.0.14.jar` | 162606 | `9493bb15b77e2ec15bc46bcff111b8d517a35747b0ddc58807cd52ebe30baa78` |
| `Waystones_1.16.5-7.6.4.jar` | 375934 | `191837d426b607a90b1263d10d45516b4482ea65cc5cdf4bf2fa2ac163912365` |
| `WitherSkeletonTweaks-1.16.5-5.4.1.jar` | 27401 | `6498891037906d09c323de6378042a8772c0748838665a257e12b4c5531c34b3` |
| `YungsApi-1.16.4-Forge-13.jar` | 106058 | `2782ffcfd0501f24089b62cc2cd001864b0e3c122c5b8ecb3dc1531bf59884c6` |

## Server Mods (134)

| File | Size | SHA-256 |
|---|---:|---|
| `abnormals_core-1.16.5-3.3.0.jar` | 975289 | `81837680e01bcf1deddb062eeea84b4f2ae67d9a69f79f48993d589d64eef2f0` |
| `accelerated-decay-forge-69.0.0.jar` | 11840 | `fe6aba0bb2e4785be15210f433c8dc653ae3130c8b9d7a2b88ca47e6914bf4ba` |
| `AdLods-1.16.5-4.1.10.0-build.0337.jar` | 107472 | `9ebd9629659f40a29a5fca84e675f029fe7576ee43768d0193a431bc38d4f2f5` |
| `AI-Improvements-1.16.5-0.5.0.jar` | 28376 | `42994ada8ac233fde3a05d9be170c3d25d671f68339c798f1e7d1dab320fbdc4` |
| `alexsmobs-1.12.1.jar` | 18135643 | `e5a29a46d1a83cfb705188168c38fbe65f0a1ac8c6126dc0f5f881ab3c1c6712` |
| `alltheores-1.3.6-1.16.5-36.1.0.jar` | 484268 | `79b137888a5a999804d55e13a3fcad1c32798e773051227e878303ad78461447` |
| `AoA3-1.16.5-3.6.11.jar` | 137118802 | `34bd44a5118f85a7af5ff61f2186adc0e022e9ed808ced37ff648b0169b6f313` |
| `Apotheosis-1.16.5-4.8.9A0.jar` | 1169760 | `bf0f3532db5811841db2fafe060a47baae875a2d1282e66e128972e4ad4d273b` |
| `appleskin-forge-mc1.16.x-2.5.1.jar` | 47721 | `6dd1d2ef1daa6871b79f5ca2ac1e757ec731f94958f12397b43670b188091b62` |
| `appliedenergistics2-8.4.7.jar` | 4820914 | `794cce73410f689e9b55f70c76d624c3e7bcb3dec843a0e9d5d0e0603f93a09e` |
| `Aquaculture-1.16.5-2.1.23.jar` | 551038 | `8530c90cea42f10fe0e0706e7ab73fe65e48d4cce8e684c3455c338196150345` |
| `aquamirae-5.4.API11.jar` | 17219961 | `cb33bc9d7abbbee4c46703a944fdd2a65926b031ce596b71773db6bf89d72aa2` |
| `architectury-1.32.68.jar` | 551889 | `e240c66919e3920d864de30138f0790072fdd72e3a27b69ba2865ab92153fba3` |
| `Artifacts-1.16.5-2.10.6.jar` | 470061 | `5563c9b47265919361ec9323c5a7a8362429747cdc3449e20023fe1bc39d2436` |
| `Atlas-Lib-1.16.5-1.1.3c.jar` | 50209 | `dd03d054f49c055beca5b327cde795ff4c944b3ccfb88cbe299573e440c50c34` |
| `AttributeFix-1.16.5-10.1.4.jar` | 9569 | `f7b42c13914392a6d5ab114e3241d094aada6f9241a2c401e4c185410aa25b8c` |
| `Atum-1.16.5-2.2.12.jar` | 4590649 | `b06ef313f1759c04a28587ceecf8c6d838ac079be55b1a89ad9aa8a58907079f` |
| `AutoRegLib-1.6-49.jar` | 57279 | `2760b765dccf1fad36e74f747ee9b1a2923e2d09eb281c72258c15bb4ed427d5` |
| `BetterCaves-Forge-1.16.4-1.1.2.jar` | 1402482 | `5182379427440bb4198790856c01f28c085365cc37ad3a05a9cd82dfdf068454` |
| `BetterCompatibilityChecker-1.0.7-build.22+mc1.16.5.jar` | 15695 | `b879e60507bd17741b8af60f00d4233b225d702e618f77ef0be9d7fcb70d8bbd` |
| `BetterDungeons-1.16.4-1.2.1.jar` | 510439 | `3cf47e1e09321c8ab7d0b2d98f4edbec865f40db14d57bbaee0cf7f1966fc7f3` |
| `betterendforge-1.16.5-2.5.jar` | 93330331 | `87c392eaf43706d579def4c973a3ccf970bbb6895cc57b72b8414eae3b9984a9` |
| `betterfpsdist-1.2.jar` | 14478 | `02af47e907b36f802818e62472811ea3b668da9bb23645120ca090707376f529` |
| `BetterMineshafts-Forge-1.16.4-2.0.4.jar` | 289307 | `19b9b7f87da2bb76574e9f3e3d18d445189a4627cfd0d8188ae88eb681b578b8` |
| `betternether_reforged-1.2.jar` | 22443866 | `a7d418801f69a513316ddeaf7b993e3f96899da4f408a90082e0fbace86bca95` |
| `BetterStrongholds-1.16.4-1.2.1.jar` | 541396 | `ca03a43d0d66b2923b830c4cac03cc1e207eba7dbf8bddb3f33f93e710bb3a1b` |
| `BetterThanMending-1.6.0.jar` | 5156 | `328981d3c31e28ff6051d622009444e80dc1f35a9454f7a1465d745f3250bc75` |
| `BiomesOPlenty-1.16.5-13.1.0.488-universal.jar` | 3651046 | `2806139055dc330a1e8f7a4324a68b6305a9eb67cc132ef09b81bdec5e89d9bb` |
| `blue_skies-1.16.5-1.1.3.jar` | 97691834 | `24da6b5f814524d65092f30100f8c863e06560e0ac55402cbf696790a218c57e` |
| `born_in_chaos_1.16_1.3.jar` | 4346948 | `6efcc1109c3b48f36633805ac203768e2a77c921fbb2aaf3e5afd1fcd1cba70a` |
| `bountifulbaubles-1.16.5-0.1.0-forge.jar` | 340889 | `75c6c24057e6907e11f3ce1af76bc34a2c584201917078385d3c922e19f8b213` |
| `bygonenether-1.3.2-1.16.5.jar` | 7682525 | `e935fbad46cee58fb71d8a14110a16faa1978f6f058b7a69dae1f5f75a9b1f79` |
| `caelus-forge-1.16.5-2.1.3.2.jar` | 41824 | `f8536bca6f45ab90388fe49b37d8612f2d27d3213d1df6d0309830cb5f99da48` |
| `carryon-1.16.5-1.15.6.24.jar` | 321769 | `0e294b86d831f5afa162c1d14cd1832541768341f92493ded9e7eb0377d06d2e` |
| `champions-forge-1.16.5-2.0.1.16.jar` | 222925 | `3998f26510dc492304111e4add8dd7cdc58d69dba6c47ef0ed76f86d25d18cbf` |
| `chunksending-1.16.5-2.5.jar` | 13027 | `fbc4293c00b33aba3c292521058b9880eeeeb652893e549727927a3d08683b0c` |
| `Chunky-1.2.123.jar` | 210906 | `ea25f65d7c8942442b8feff17a1c86a5e5f6706bf95ff17ee7711ea193721e37` |
| `citadel-1.8.1-1.16.5.jar` | 482439 | `4c78a18f309aa9895ff6ef70fc3140c436c729fa84c832770ec30970daaab88a` |
| `Clumps-6.0.0.28.jar` | 18397 | `f69abc1d44277b495004fd6d67d0f95f2574581bb26e55543f2dcd2153cd92d0` |
| `collective-1.16.5-5.49.jar` | 189273 | `eea0121bbad3eefbbe0283d18758decba872e1d2f1fef8352a24f0a9f9d586d7` |
| `connectivity-2.3-1.16.5.jar` | 52995 | `07f1a43915116527e488bad92609516f1c241a64d8c9c887e6a9f522f8accfe3` |
| `coroutil-forge-1.16.5-1.3.6.jar` | 37129 | `cd9a94de2ccffa29fa18466665bd980abf021acb140632e20d7047165f047382` |
| `corpse-1.16.5-1.0.6.jar` | 203988 | `c3b1e2ac93165045f7eb88871e06d5269ee4ca0bf41a46bb86f62075c9f778ef` |
| `Craziniess Awakened.jar` | 226446 | `0ceca339e720cc9bbd43fc23bc89682f57e22624060930204c854b8b3ef53d31` |
| `curios-forge-1.16.5-4.1.0.0.jar` | 291897 | `952a276d7a2c8fdef29794711b73bfa308e7fd96ec1e2d51750523456d9f892b` |
| `curiouselytra-forge-1.16.5-4.0.2.5.jar` | 35474 | `28cc8251e25a9aeec023f1e2783264bd780fb765464b9f58732dc815e4d2436a` |
| `CustomNPCs-1.16.5-GBFix-Unofficial-20250630.jar` | 12686594 | `962e276188e89d75fd9a20d46f10e61ba1a455143796cda1d8af409473de5a8c` |
| `DivineRPG-1.8.27.jar` | 18216367 | `dec4318b729f77dc5015b2c147fd85a53208b364b4d80507e9056618069f5595` |
| `dragonfight-1.8.jar` | 29608 | `1d02462824141cb11b6fbb79117cb9b922df5ed12740e92e10b9d446ca4d1282` |
| `DungeonCrawl-1.16.5-2.3.12.jar` | 797023 | `1b3966775743ed8a3389dbe59027b1fad98f70e6da93c278530e5aec3575b0cf` |
| `dungeons_enhanced-1.16.5-1.9.2.jar` | 1071358 | `44c998f63aabfa0f17b498d9de449eb08e9fdf18e626fc122e243853988315c9` |
| `dungeons_gear-1.16.5-3.2.7.jar` | 3072823 | `75841c6284daca5c95f7fab1a30f95b6a0f556d66e0135d0c3e158a78d456a61` |
| `dungeons_libraries-1.16.5-1.0.6.jar` | 647661 | `9b99900e4f0d7e9e5952f6944c17cbfb8ccfb03bfced9d161f0d47584637a78d` |
| `dungeons_mobs-1.16.5-2.2.3.jar` | 12420294 | `0437a6732963a7399240b9112cadce6a72d6b872989774ec7ada76179c338fdc` |
| `DungeonsArise-1.16.5-2.1.49-beta.jar` | 5544981 | `2d60816a6ebdbc031e06b06b548d9c94836af3d3b4c6b81870aa1221054a666a` |
| `endergetic-1.16.5-3.0.2.jar` | 11036888 | `4f1e17ee38cb18a663e03e7e10cdddae836c5850bbbde66ea054dcefa042a22f` |
| `endrem-5.0.3-R-1.16.X.jar` | 1644035 | `bf782c56f8edb4d0ea43b9ec98ce7e7b2b398d1779a9418fa670c7b0602f6b18` |
| `EnigmaticLegacy-2.11.12.jar` | 1516976 | `6d831bd40f99b2112f42d168355da611389dfe48a1098c12f2302423b64d53e7` |
| `expandability-2.0.1-forge.jar` | 43358 | `0959cffb3a545730e6b2e1377bb89b59ff96e7f9142f54cc8035ab4fa2fc76e1` |
| `farsight-1.7.jar` | 10183 | `6aabe8b3689eaf73be45728966459db110e0351427d802abfa6256e7a5557715` |
| `fastboot-1.16.x-1.1.jar` | 24684 | `db208c8df5b6aed46fb4e30af19766ef568aef50bce664329392ffb1cb9cf3f4` |
| `FastFurnace-1.16.5-4.5.0.jar` | 5907 | `fc384eeb166b8610e2f21b4f14e3341285744370b56fbb52d91bd4ee4bb8f106` |
| `FastSuite-1.16.4-1.1.1.jar` | 10829 | `3195239313100586bfa2f4dd02c5da0e20d7cfd5f7c00b8147efc2842f235be6` |
| `FastWorkbench-1.16.5-4.6.2.jar` | 22470 | `36f00c55c8414467a40f784d15a4f6a24406a8847703cbbd73033df1f7c18526` |
| `ferritecore-2.1.1-forge.jar` | 108557 | `9aec89734cdf8cb0ee31649e3f6aab9c04f2621eddecff8e31ccdfe18cf8e87a` |
| `ForgeEndertech-1.16.5-7.3.0.0-build.0330.jar` | 542410 | `6435fbe173052e38808a60a5eacf1f8188a0fb3befba9059ff7bf32b86fdc311` |
| `ftb-library-forge-1605.3.4-build.90.jar` | 585125 | `f2bd3aa612d959eb10e7cb9b212c11cd9b6625fc9172ecbc24c9b804f0fe9e8b` |
| `ftb-ultimine-forge-1605.3.1-build.45.jar` | 78597 | `3a045ebcdf4ce291022497b1889054d0dd6137075dffc3a3abfc3682fdcf9bee` |
| `GatewaysToEternity-1.16.5-1.0.2.jar` | 564724 | `7cf60c0e09ebc4d5e9929c426e4c202dfd857c93f37241d31d65e434c27ae41f` |
| `geckolib-forge-1.16.5-3.0.106.jar` | 3559283 | `e130cde6859858ac2a5f8d641794d97d85400c8925c3b46fb19e1a2ea286a6ca` |
| `goblintraders-1.7.3-1.16.5.jar` | 428711 | `e2c1168ccd3f072257825f4a61e6175c40a3cf59dc124f9d54b59361fb20616b` |
| `guardvillagers-1.16.5.1.2.4.jar` | 188171 | `7b7764c511271db4cc5806768ca1d2c68522cae7ba415d6249d1756915a5c4ef` |
| `Hats-1.16.5-10.3.4.jar` | 1544164 | `f85f3af9222a2752f5620e5c1c225f4a0af2e610b96180c821770f0723194617` |
| `iceandfire-2.1.12-1.16.5-patch-1.jar` | 21463531 | `29e66bd0199169649f6de4e4b0ef00a67555eb348f10b8d01794c20d67f128c8` |
| `iChunUtil-1.16.5-10.7.0.jar` | 597557 | `45726157333a986d9123958ede53f09b7da3f20e88b496f715bbf5e7a4162b8b` |
| `infernal-expansion-1.16.5-2.5.0.jar` | 14629220 | `df2e79d4e019e80d2ea593a17c309237ac80481ed202f4d4cb7ae1b3c79ac364` |
| `InsaneLib-1.4.2-mc1.16.5.jar` | 45677 | `7bef0a474d0e520e0bb00488ed3575c96657e1e24941eb419b4a10a48a1b6b5c` |
| `inventorysorter-1.16.1-18.1.0.jar` | 49966 | `afb49ff93fdd9590a3d39a04df4fabef32afce0e331fe40339fe6b10e3091d6e` |
| `ironfurnaces-1.16.5-2.7.7.jar` | 493742 | `1203c7ddd5e6d36a7db144f8f425f3d7b23acd89452208fa7d0da5c8c298bba6` |
| `itemcollectors-1.1.12-forge-mc1.16.jar` | 99093 | `d5622aaf09238d00c78ae8a44e4fa5bdfa96232d82048a18582c917deae0388b` |
| `L_Enders Cataclysm-0.48 Changed Theme -1.16.5.jar` | 12700153 | `617c92ad1a3b970aa27201f8a26f3c356dc16571a45a64f8fb3ec89cfd01c6fc` |
| `letmedespawn-forge-1.3.2b.jar` | 85166 | `c7f8d88fa26b70e70bf012f3438d7e23b56050a73d34d43abdbd6a50c372fed3` |
| `LightAura-4.4.0.jar` | 18705 | `358ff6f2f64219561f5fd57e5025f66dd9f1ff02231f64195ad2c28fdbe7df42` |
| `lootr-1.16.5-0.2.19.52.jar` | 377041 | `14e9069f2a053d20436f3dcf445a69d94ffc59e6d5aa1eed4c6e417469db9d10` |
| `lucky-block-forge-1.16.5-6.0.jar` | 1921940 | `f842dec8095394aed3332bfd773f26c5f683bf339473279449d3fcf009395016` |
| `MaxHealthFix-Forge-1.16.5-1.0.5.jar` | 6725 | `bab21006279f6d6d018764a511fe0e06b9437cfe5d8a1ded61d8d44a8601b00b` |
| `meetyourfight-1.16.5-1.2.0.jar` | 2003393 | `f6a71bd6a2206e8b90068dba66921da1817438622db8456a9c7831e9d42be3ef` |
| `mobile-trashcan-1.0.0-backport-1.16.5.jar` | 67567 | `06d6344a874363acd0f404b3e7c93fa1903e5d82edb405c04ebae1339d5d10d2` |
| `MobsPropertiesRandomness-3.3.0-mc1.16.5.jar` | 110479 | `2cf244eb10fa3c9d90ddda0553905aef4c923ad0527204d1173f00496002f78e` |
| `modernfix-forge-5.18.0+mc1.16.5.jar` | 867079 | `17ff7a1096275e1c6706a8f65d3f903b5eccb4a979f4aeb5b4302b3966c5bde8` |
| `Morph-1.16.5-10.2.1.jar` | 1277555 | `f5a150ae5952c8e12829c0c1375d62ef337d325d87dc13aa1885b90bef70b0da` |
| `mowziesmobs-1.5.27.jar` | 13557419 | `1c35253f5c3f85591ab5ccdffdef9777433ae2c3eb54fbae1bdf77146a6681d3` |
| `MutantBeasts-1.16.4-1.1.3.jar` | 1289476 | `1d008fed88518398ed960d4e291ead910fd23e9e1d854436760716ab74c2af00` |
| `NaturesCompass-1.16.5-1.9.1-forge.jar` | 203573 | `f5f94447b6fde00eb450ba18236ce77a2f3f05998cf250841813afdf4b3303cd` |
| `obscure_api-11.jar` | 859106 | `1c2d5c8976b7d4b4e298b3f30de78bc53eb3c1d288ec8c67e3af9a224ba88b07` |
| `OuterEnd-0.2.14.jar` | 57328296 | `ae0a9d00fb5f20bd867c758175ac0fd6ed35191469904da78c1eee095dc55ad3` |
| `pandorasbox-2.2.6-1.16.5.jar` | 375701 | `91c6a1f560dc06380a68c3c7316db30ad8eeb3c0801b857f977d7446d218a082` |
| `Patchouli-1.16.4-53.3.jar` | 593352 | `691b66041157601d1b89e7ff66d1d7ab08b97a3f1163caf600bfaceef5a1cc88` |
| `Pehkui-3.8.2+1.16.5-forge.jar` | 674598 | `9f9aa89ddbc4a80b0c508c55aa25a3120f769e8aefacc68e22c06293aeb557fe` |
| `PickUpNotifier-v1.2-1.16.3.jar` | 42604 | `048cebf7c8ff0ec94ca30cafb4e22e2839e419e69082cbad2d5cd2de247aac13` |
| `Placebo-1.16.5-4.7.1.jar` | 174158 | `eef4835343a46cc3c45776d905b52aced3f3b233d00a04ba646aaa9c6111b789` |
| `ProjectE-1.16.5-PE1.0.2.jar` | 2099991 | `626f0d0e8b9e044e4d6742c61925389babe4efdc42aaaceceb7b826418b62b11` |
| `puffish_skills-0.5.0-1.16.5-forge.jar` | 300512 | `282437fa05245b91b4ec7184c6bb283b1450682d4b52d4046dd8703255cde4c7` |
| `Quark-r2.4-322.jar` | 8796901 | `dcbccfaf08982ff7d8e11c6c4b54de75ad161317d5b69bcefe2e3c009040db25` |
| `realmrpg_fallen_adventurers_0.2.0_forge_1.16.5.jar` | 332998 | `6db2b382a1f35f657b5496ec66887f17efbc7ed583251003d184db1c29f8b234` |
| `relics-1.16.5-0.3.4.4.jar` | 1118083 | `b70dcf699d2d4cf8a8235a824c772612b880d6f76d6fc42c83b67e21bcc2c6be` |
| `remodifier-1.16.5-2.2.3.jar` | 91799 | `ab8629de02bafde2bb8e96ff5cc1c19cb13e48bf43189b857c027b358747d809` |
| `repurposed_structures_forge-3.4.7+1.16.5.jar` | 5576490 | `b1dda698ebe52b2508c306eae73d51951fe7e9ffceea42b9fc966500eb5ecd35` |
| `RoadRunner-mc1.16.5-1.5.2.jar` | 393531 | `7312852ccf34b21b8dbeeb077796e082a141747082e686bba8882ae68cd9907f` |
| `savageandravage-1.16.5-3.2.0.jar` | 1271118 | `4bb51b03efb4efd0fdb6d750789d13f87522e4ab4e2c23f53ebbb842b2bc4151` |
| `ScalingHealth-1.16.5-4.1.5+11.jar` | 513375 | `f0d7538b7dbdbce23d369cec592fe7ad2c60951aa38b73ef1b5ec8f2d246f04c` |
| `silent-gear-1.16.5-2.6.30.jar` | 2583204 | `cdcdfd9d45d2a18a5a35e04f9f812bbde9a4ad373445aac644d623f1c3dfc17c` |
| `silent-lib-1.16.3-4.9.6.jar` | 247616 | `ccd8757d3a8b5447bb4192c1966099cd3671b2f7e49fb0d889f32359ad2d2d45` |
| `smarterfarmers-1.16.5-1.2.1.jar` | 33716 | `405f87a08ea15ed6bc4d1c57dc8d4d6a5b6b7898a51a9b30a88fd31ebdd6e34a` |
| `smoothchunk1.16.5-2.0.jar` | 14157 | `e7ab1d4fd31ee8e8be75a711df7b403d54a86514432302c8ad79a87851a2bc26` |
| `spark-1.9.1-forge.jar` | 3157081 | `e0e10f3ba3c4169d4fe1408f4f9b081bb1f36e4cdf3777a26beab816057817e3` |
| `SpartanWeaponry-1.16.5-2.2.2.jar` | 1660410 | `7c956831c3a280b04b6227b05178b82429623ffed539f919a4e90c65763a8334` |
| `stalwart-dungeons-1.16.5-1.1.7.jar` | 1542647 | `0502fdf83f471c520ab0894f3e50afd5f7067c09fd96dccd44f6646133287e44` |
| `structure_gel-1.16.5-1.7.8.jar` | 261390 | `f35cefe2536ec37604c46a9e745ad5c8255eef37be4d88992dbd365a484880a8` |
| `supermartijn642configlib-1.1.6-forge-mc1.16.jar` | 205206 | `8a29776877e176b127fad0f3a9e8b193150b2a478b9f9629bdd3c4878df416ed` |
| `supermartijn642corelib-1.1.21-forge-mc1.16.jar` | 541853 | `5a180e7d63d3b916132bebd2e673779c5bf4b24a1ab6b9adf0d3ec7a3d17ca20` |
| `takesapillage-1.0.3-1.16.5.jar` | 3764552 | `d9e45dccaf587d2f50df5104cffecbc429dd57b63bd29174e0b46bc90f776aaa` |
| `Terraria Trinkets - 1.0.1 [1.16.5].jar` | 93141 | `830cb896b73f3d68594ff63e0c52d2c525c1a8d2d81dd67c23ba19988073f3bb` |
| `The_Undergarden-1.16.5-0.5.5.jar` | 63449848 | `a4ba8e7d844b80c1417d2da4579226de3a4bc77a4723aea1e08e2d7c803ade1d` |
| `TheAbyss2 2.2.3-4 1.16.5.jar` | 59405125 | `ffc1c7bd80251a3a5de593a8624eda85e6f414f98855177181319e35a88662d1` |
| `The-Hordes-1.16.5-1.1.5c.jar` | 198825 | `ff47da6155dd21faa72bb934c69cabaa6499894cf99f2d3cdad30ddb490ee250` |
| `towers_of_the_wild-1.16.3-2.1.0.1.jar` | 157147 | `98436d28cf075f48fc8998fc2039df059dc5bdfae128a3cecda705fb65e8455a` |
| `treeharvester_1.16.5-5.9.jar` | 22982 | `5d2262b4703bb2fbfaa829dd5bfa61aef080f3366b5316bef864e56c42d2081e` |
| `twilightforest-1.16.5-4.0.870-universal.jar` | 31748538 | `85c53f5332d54ff2890083764db8a61cb5c507638959a17a4769d73ba19006ad` |
| `upgrade_aquatic-1.16.5-3.1.2.jar` | 3682686 | `b14d6f3d8a1ba8a820a3d11e7cfe2d7b65ec84cb2b26f7859d76bab5d473d845` |
| `watut-forge-1.16.5-1.0.14.jar` | 162606 | `9493bb15b77e2ec15bc46bcff111b8d517a35747b0ddc58807cd52ebe30baa78` |
| `Waystones_1.16.5-7.6.4.jar` | 375934 | `191837d426b607a90b1263d10d45516b4482ea65cc5cdf4bf2fa2ac163912365` |
| `WitherSkeletonTweaks-1.16.5-5.4.1.jar` | 27401 | `6498891037906d09c323de6378042a8772c0748838665a257e12b4c5531c34b3` |
| `YungsApi-1.16.4-Forge-13.jar` | 106058 | `2782ffcfd0501f24089b62cc2cd001864b0e3c122c5b8ecb3dc1531bf59884c6` |

## Config Files (1)

| File | Size | SHA-256 |
|---|---:|---|
| `modernfix-mixins.properties` | 203 | `1a477ecd627bbe94b45e2b7f6b5c097b448486650d735c9a745029f5518f983e` |

## Shaderpacks (1)

| File | Size | SHA-256 |
|---|---:|---|
| `ComplementaryReimagined_r5.8.1.zip` | 546925 | `3f1cd389e717b2e62f58edff222059b9c60de71b14bb49b517eb58318ce35b15` |
