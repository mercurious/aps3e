// SPDX-License-Identifier: WTFPL
package aenu.aps3e;

import android.app.Activity;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.webkit.WebView;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.TextView;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;

public class AboutActivity extends AppCompatActivity {


    public static String get_update_log(){
        // Bilingual changelog: original Chinese (from upstream aenu1/aps3e) followed by an English
        // translation on each line, with the community "Shader Patch Edition" additions appended
        // at the end in the same style. Commented-out author notes are left verbatim.
        final String log="\n"
                +"0.1(2025-01-06)\n"
                + " *首个版本 — First release\n"
                +"0.2(2025-01-13)\n"
                + " *修正socket无法创建的bug — Fixed a bug where sockets couldn't be created\n"
                + " *添加更新日志 — Added the update log\n"
                + " *新的用户界面 — New user interface\n"
                + " *修正了一个iso安装的bug — Fixed an ISO install bug\n"
                + " *修正了cpu架构检测错误的bug — Fixed a CPU-architecture detection bug\n"
                + " *添加.nomedia禁止媒体存储扫描 — Added .nomedia to stop media-store scanning\n"
                +"0.3(2025-01-14)\n"
                + " *游戏界面设置为全屏 — Game view set to fullscreen\n"
                + " *日志行为修改 — Logging behavior changes\n"
                + " *初步完善虚拟键盘 — Initial virtual keyboard\n"
                + " *移除sharedUserId属性用于兼容安卓13+ — Removed sharedUserId for Android 13+ compatibility\n"
                + " *修正了压缩纹理卡死的bug — Fixed a hang with compressed textures\n"
                + " *虚拟键盘增加L2,L3,R2,R3 — Added L2/L3/R2/R3 to the virtual pad\n"
                +"0.4(2025-01-17)\n"
                + " *修正了统一缓冲区更新卡死的BUG — Fixed a hang in uniform-buffer updates\n"
                + " *修正了多线程按键资源访问冲突导致的闪退 — Fixed a crash from multithreaded input resource conflicts\n"
                + " *同步部分代码以解决卡奖杯的问题 — Synced some code to fix trophy hangs\n"
                + " *BC纹理格式支持 — BC texture format support\n"
                + " *虚拟键盘位置调整 — Virtual keyboard position adjustments\n"
                + " *加入了图标(Icons/ui/*) — Added icons (Icons/ui/*)\n"
                + " *游戏准备阶段消息变更 — Game-prep stage messages changed\n"
                +"0.5(2025-02-19)\n"
                + " *右摇杆控制修复 — Right-stick control fix\n"
                + " *站点搭建完成，欢迎访问😄 — Website is up, come visit 😄\n"
                + " *支持pkg格式安装 — PKG install support\n"
                + " *初步的英语本地化支持 — Initial English localization\n"
                + " *启动失败显示错误信息(目前效果很烂) — Show error info on launch failure (still rough)\n"
                + " *PS键追加 — Added the PS button\n"
                +"0.6(2025-02-23)\n"
                + " *LR键位修正 — L/R button fixes\n"
                + " *加入按键映射(目前还无法正常使用) — Added key mapping (not usable yet)\n"
                + " *加入虚拟键盘一定时长自动隐藏 — Virtual keyboard auto-hides after a delay\n"
                + " *加入鸣谢列表 — Added a credits list\n"
                + " *加入虚拟键盘编辑 — Added virtual-keyboard editing\n"
                + " *新的图标，由Ruban提供 — New icon, provided by Ruban\n"
                +"0.7(2025-03-02)\n"
                + " *修正了部分着色器缓存相关的BUG，目前可以启用了 — Fixed shader-cache bugs; it can be enabled now\n"
                + " *更新LLVM至19.1 — Updated LLVM to 19.1\n"
                + " *修正了设备不支持depthClamp闪退的问题 — Fixed a crash on devices without depthClamp\n"
                + " *修正按键映射 — Fixed key mapping\n"
                + " *安装PKG/ISO时自定义路径 — Custom path when installing PKG/ISO\n"
                +"0.8(2025-03-06)\n"
                + " *支持的最低版本更新为Android 8.1(API27) — Minimum supported version raised to Android 8.1 (API27)\n"
                + " *音频后端更改为AAudio — Audio backend changed to AAudio\n"
                + " *修正按键映射(LR) — Fixed key mapping (L/R)\n"
                + " *载入着色器缓存界面修正 — Fixed the shader-cache loading screen\n"
                + " *同步部分代码以解决压缩纹理问题 — Synced some code to fix compressed textures\n"
                + " *降低编译PPU模块线程数量为4，防止部分设备爆内存 — Lowered PPU-module compile threads to 4 to avoid OOM on some devices\n"
                +"0.9(2025-03-24)\n"
                + " *3D纹理修正(未测试) — 3D texture fix (untested)\n"
                + " *同步部分代码以解决GCM事件问题 — Synced some code to fix GCM event issues\n"
                + " *同步部分代码(多个修正) — Synced some code (several fixes)\n"
                + " *增加了设置界面(不能用，还没做完) — Added a settings screen (not usable, unfinished)\n"
                + " *完善了设置界面 — Completed the settings screen\n"
                + " *修复了退出死锁的问题 — Fixed an exit deadlock\n"
                +"0.10(2025-04-06)\n"
                + " *调整默认色彩格式为RGBA — Default color format set to RGBA\n"
                + " *后端结构调整，修正了顶点更新的问题 — Backend restructure; fixed a vertex-update issue\n"
                + " *同步部分代码(0328) — Synced some code (0328)\n"
                + " *修正了PS键界面无字的问题 — Fixed missing text on the PS-button screen\n"
                + " *修正了消息框无字的问题 — Fixed missing text in message boxes\n"
                + " *颜色修正 — Color fixes\n"
                + " *返回键弹出退出框 — Back key shows the exit dialog\n"
                + " *默认配置调整 — Default config adjustments\n"
                +"0.11(2025-04-24)\n"
                + " *更新glslang至15.2.0 — Updated glslang to 15.2.0\n"
                + " *数据目录调整 — Data directory changes\n"
                + " *支持自定义驱动 — Custom driver support\n"
                + " *设置界面完善 — Settings screen improvements\n"
                + " *修复了应用后台崩溃 — Fixed a background crash\n"
                + " *实现了SaveDialog — Implemented SaveDialog\n"
                + " *实现了奖杯通知 — Implemented trophy notifications\n"
                + " *游戏安装行为变更 — Game install behavior changed\n"
                +"1.12(2025-04-27)\n"
                + " *修正了奖杯通知和存档界面 — Fixed trophy notifications and the save screen\n"
                + " *顶点buffer初始值修正 — Fixed vertex-buffer initial value\n"
                +"1.13(2025-05-01)\n"
                + " *添加顶点buffer更新模式选择 — Added vertex-buffer update-mode selection\n"
                + " *添加了文件夹格式支持 — Added folder-format support\n"
                +"1.14(2025-05-08)\n"
                + " *调整默认字体为来自固件，防止Android15崩溃 — Default font now from firmware (avoids an Android 15 crash)\n"
                + " *添加了字体选择 — Added font selection\n"
                + " *关于界面调整，获取cpu/gpu信息变更 — About screen changes; CPU/GPU info retrieval changed\n"
                +"1.15(2025-05-12)\n"
                + " *虚拟键盘UI更新 — Virtual keyboard UI update\n"
                + " *虚拟键盘编辑更新（可调整大小，重置） — Virtual keyboard editing (resize, reset)\n"
                +"1.16(2025-05-16)\n"
                + " *修复全屏模式左侧黑边 — Fixed the left black bar in fullscreen\n"
                + " *自定义驱动|字体路径，以列表形式显示 — Custom driver/font paths shown as a list\n"
                + " *添加设置选项 重置为默认 — Added a \"reset to default\" setting\n"
                +"1.17(2025-05-20)\n"
                + " *ISO格式支持 — ISO format support\n"
                + " *菜单调整 — Menu adjustments\n"
                + " *修复文件管理无法删除目录的问题 — Fixed file manager unable to delete directories\n"
                +"1.18(2025-05-24)\n"
                + " *完善ISO支持 — Improved ISO support\n"
                + " *追加了MsgDialog,OskDialog — Added MsgDialog and OskDialog\n"
                +"1.19(2025-05-28)\n"
                + " *载入时加载背景图(ISO) — Show a background image while loading (ISO)\n"
                + " *修正了ISO支持 — Fixed ISO support\n"
                + " *修正和完善了主界面的上下文菜单 — Fixed and improved the main-screen context menu\n"
                //+ " *支持了16kb页\n"
                + "1.20(2025-06-03)\n"
                + " *修复了自定义驱动不生效的问题 — Fixed custom driver not taking effect\n"
                + " *设置清理与调整 — Settings cleanup and adjustments\n"
                + " *修正了删除游戏数据不生效的问题，添加删除着色器缓存选项 — Fixed delete-game-data not working; added a delete-shader-cache option\n"
                + "1.21(2025-06-11)\n"
                + " *更改纹理格式为RGBA — Changed texture format to RGBA\n"
                + " *设置完善 — Settings improvements\n"
                + "1.22(2025-06-16)\n"
                + " *默认使用cpu处理纹理(用于修复Adreno 7xx默认驱动崩溃的问题) — Use CPU for textures by default (fixes an Adreno 7xx default-driver crash)\n"
                + " *检测并阻止启动无法解密的游戏 — Detect and block launching undecryptable games\n"
                + " *清理无效的主菜单（PS3）选项 — Removed invalid main-menu (PS3) options\n"
                + " *修复游戏数量较多时刷新列表会产生ANR的问题 — Fixed an ANR when refreshing the list with many games\n"
                + " *增加选项（纹理更新模式） — Added an option (texture update mode)\n"
                + " *增加选项（字体大小） — Added an option (font size)\n"
                //+ " *修复UB\n"
                //+ " *协议追加\n"
                + "1.23(2025-06-19)\n"
                + " *优化了主菜单界面 — Improved the main-menu UI\n"
                + " *修复了按键映射无效的问题 — Fixed key mapping not working\n"
                + " *增加了选项使用BGRA格式并默认启用 — Added a BGRA-format option, enabled by default\n"
                + " *设置优化（库控制排序，进度条可编辑） — Settings polish (library control sorting, editable progress bar)\n"
                + "1.24(2025-06-24)\n"
                + " *统一界面风格 — Unified the UI style\n"
                + " *修复了方向键和摇杆 — Fixed the d-pad and sticks\n"
                + " *可为游戏创建单独的配置 — Per-game configurations\n"
                + " *增加些调试功能 — Added some debug features\n"
                + "1.25(2025-06-30)\n"
                + " *虚拟键盘更新，增加动态摇杆，可设置组缩放 — Virtual keyboard update: dynamic stick, group scaling\n"
                + " *增加了按键震动 — Added button vibration\n"
                + " *更改ffmpeg版本为5.1.6 — Changed ffmpeg to 5.1.6\n"
                + "1.26(2025-07-09)\n"
                + " *调整风格为跟随系统 — Style follows the system theme\n"
                + " *加入了快速开始页面 — Added a Quick Start page\n"
                + " *修正了强制转换纹理选项 — Fixed the force-cast-texture option\n"
                //+ " *自定义配置可重置为默认\n"
                //+ " *适配目标版本为安卓15\n"
                + " *修正删除着色器缓存无效的问题 — Fixed delete-shader-cache not working\n"
                //+ " *添加自定义驱动(*.zip)时自动处理命名\n"
                + "1.27(2025-07-19)\n"
                + " *修复未开启 使用BGRA格式 选项时产生的颜色错位 — Fixed color misalignment when the BGRA option was off\n"
                + " *设置和主界面更新 — Settings and main-screen updates\n"
                + " *修复部分ISO不识别的问题 — Fixed some ISOs not being recognized\n"
                + " *可禁用虚拟键盘 — Virtual keyboard can be disabled\n"
                + " *加入日语，韩语和繁体中文的支持 — Added Japanese, Korean, and Traditional Chinese\n"
                + "1.28(2025-07-29)\n"
                + " *在Adreno 5xx/6xx设备上延迟0.5秒加载动态库和主界面，以修正其无法启动的问题 — Delay dynamic-lib and main-screen load by 0.5s on Adreno 5xx/6xx to fix startup\n"
                + " *增加添加快捷方式选项 — Added a create-shortcut option\n"
                + " *修正游戏重入后按键输入无效的问题 — Fixed input not working after re-entering a game\n"
                + " *增加线程亲和力掩码选项 — Added a thread-affinity-mask option\n"
                + " *新增法语，俄语等共18种语言支持 — Added 18 languages (French, Russian, and more)\n"
                + "1.29(2025-08-19)\n"
                //+ " *游戏退出项优化\n"
                + " *启动时检测设备是否支持Vulkan — Check Vulkan support at startup\n"
                + " *使用高精度的计时器 — Use a high-precision timer\n"
                + " *同步部分RPCS3更新 — Synced some RPCS3 updates\n"
                + "1.30(2025-08-20)\n"
                //+ " *同步部分RPCS3更新（0820）\n"
                + " *回退掉RPCS3更新 — Reverted the RPCS3 update\n"
                + "1.31(2025-10-17)\n"
                + " *修复iso文件内日期不解析的bug — Fixed ISO internal dates not parsing\n"
                + " *修复sys_fs解析iso目录的问题 — Fixed sys_fs parsing of ISO directories\n"
                + " *打开DG类游戏时，自动安装PKG（需要删除config/dev_hdd0/game/$locks目录一次） — Auto-install PKG when opening DG-type games (delete config/dev_hdd0/game/$locks once)\n"
                + " *可安装edat — Can install edat\n"
                + "1.32(2025-11-06)\n"
                + " *修复多个bug — Fixed several bugs\n"
                + " *界面更新 — UI update\n"
                + "1.33(2025-12-01)\n"
                + " *修复每次更新时按键错位的问题 — Fixed input misalignment on each update\n"
                + " *添加显示奖杯信息选项 — Added a show-trophy-info option\n"
                + " *添加创建/删除PPU缓存，删除SPU缓存选项 — Added create/delete PPU cache and delete SPU cache options\n"
                + "1.34(2025-12-26)\n"
                + " *优化创建PPU缓存 — Optimized PPU cache creation\n"
                + " *内存搜索/写入（未测试） — Memory search/write (untested)\n"
                + "1.35(2025-12-26)\n"
                + " *移除创建PPU缓存选项（谷歌play没通过） — Removed the create-PPU-cache option (didn't pass Google Play)\n"
                + "1.36(2026-02-24)\n"
                + " *修复方向键 — Fixed the d-pad\n"
                + " *修复DLC不生效（.iso) — Fixed DLC not working (.iso)\n"
                + " *修复设置界面旋转崩溃 — Fixed a settings-screen rotation crash\n"
                + " *部分调整与优化 — Various adjustments and optimizations\n"
                + "1.37(2026-03-21)\n"
                + " *适配不支持触屏的设备 — Support devices without a touchscreen\n"
                + " *增加用户数据管理页面 — Added the User Data Manager page\n"
                + " *优化了内存搜索 — Optimized memory search\n"
                + "1.38(2026-04-13)\n"
                + " *部分修正与完善 — Various fixes and improvements\n"
                + "2.39(2026-05-29)\n"
                + " *更新RPCS3版本 — Updated the RPCS3 version\n"
                + " *加密版ISO支持（需要对应的.dkey或.key文件） — Encrypted ISO support (needs the matching .dkey or .key file)\n"
                + "Shader Patch Edition - community fork by mercurious (2026-06-15)\n"
                + " *持久化VkPipelineCache：每个游戏预热一次后大幅缩短编译着色器过程 — Persistent VkPipelineCache: shrinks the \"Compiling shaders\" pass after one warm-up boot per game (fork PR #122)\n"
                + " *修复GT高内存崩溃：描述符池按需增长而非泄漏 — Fixed the Gran Turismo high-memory crash: descriptor pools now grow on demand instead of leaking (backport of RPCS3 #18844, fork PR #127)\n"
                + " *恢复游戏内加载转圈图标和屏幕按键图标（打包Icons/ui） — Restored the in-game loading spinner and on-screen button glyphs (bundled Icons/ui, fork PR #128)\n"
                + " *新增着色器缓存管理：导出/导入游戏的可移植着色器缓存 — New Shader Cache Manager: export/import a game's portable shader cache (fork PR #129)\n"
                + " *导出的缓存现在注册到MediaStore，可在文件App中显示 — Exported caches now register with MediaStore so they appear in the Files app\n"
                + "Shader Patch Edition (cont.) - 2026-06-16\n"
                + " *ETK Cockpit：逐帧精确的手柄输入录制/回放（通过 cellPadGetData 挂钩，按游戏读取节奏对齐，可跨冷启动复现）。三标记方案（R1+下方向键组合键）：起跑点 MARK-IN、过起跑线 MARK-OFFSET、结束 MARK-OUT；回放时在起跑线重新对齐游标，规避 GT5P 强制滚动起步的不可复现偏移 — ETK Cockpit: frame-exact gamepad input record/replay via a cellPadGetData hook (keyed to the game's read cadence, survives a cold boot). Three-mark scheme (R1+D-pad-Down chord): MARK-IN at the rolling start, MARK-OFFSET at the lap line, MARK-OUT at the end; replay re-syncs the cursor at the lap line to defeat GT5P's non-reproducible rolling-start offset — fork branch pad-movie\n"
                + " \n";

        return log;
    }
    public static String gratitude_list(){
        //gratitude_content
        final String list="\n"

                + " callmerabbitz\n"//
                + " collazof\n"//
                + " devyprasetyo33\n"
                + " 再见某人\n"
                + " 同人小说\n"
                + " 糖ωσ心の爱\n"
                + " 不表态不经手不参与\n"
                + " VM GAMEDROID\n"
                + " brothason\n"
                + " gamerpro\n" //
                + " geovanem5\n"
                + " edjeffher33\n"
                + " Chakiel Zero Android\n"//
                + " Darwinp\n"//
                + " geovanem5\n"
                + " sarahi\n"
                + " melkygt0\n"
                + " Gratitud e\n"
                + " mediafire40\n"
                + " klekot\n"
                + " agustocastillo101\n"
                + " Paul\n"
                + " bakerrichard69\n"
                + " Bardok84\n"
                + " wingcom007\n"
                + " Max\n"
                + " kelve.p\n"
                + " Sophia\n"
                + " gonzaloinversionista\n"
                + " josekelvin482\n"
                + " superfuffa87\n"
                + " kim81austin\n"
                + " jblanm005\n"
                + " dlt31795\n"
                + " XZeusZX\n"
                + " neucorazaocleon98\n"
                + " Kyujj17\n"
                + " Ryan.p\n"
                + " 妖妖\n"
                + " 太空飞瓜\n"
                + " 明\n"
                + " 萌酱的小可爱\n"
                + " edjeffher33\n"
                + " fernandez21\n"
                + " yamil\n"
                + " matschilui2\n"
                + " 超玩游戏盒\n"
                + " 冰糖\n"
                + " christopher\n"
                + " dalelace\n"
                + " sandroloez\n"
                + " 石头\n"
                + " 鑫晓宇\n"
                ;

        String l= list.replace("\n","\n    *");
        l.substring(0,l.length()-1);
        return l+"\n\n";
    }
    TextView text;
    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        supportRequestWindowFeature(Window.FEATURE_NO_TITLE);
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_about);

        // 设置 Toolbar
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        if(getSupportActionBar()!=null) {
            getSupportActionBar().setTitle(R.string.about);
        }

        text=findViewById(R.id.about_text);
        findViewById(R.id.gratitude).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                text.setText(getString(R.string.gratitude_content)+gratitude_list()+getString(R.string.gratitude_content2));
            }
        });
        findViewById(R.id.open_source_licenses).setOnClickListener(new View.OnClickListener() {
            void show_licenses_dialog(){
                AlertDialog.Builder ab=new AlertDialog.Builder(AboutActivity.this);
                ab.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface p1, int p2) {
                        p1.cancel();
                    }
                });
                WebView wv=new WebView(AboutActivity.this);
                wv.loadUrl("file:///android_asset/licenses.html");
                ab.setView(wv);
                ab.create().show();
            }
            @Override
            public void onClick(View v) {
                show_licenses_dialog();
            }
        });
        findViewById(R.id.update_log).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                text.setText(get_update_log());
            }
        });
        ((CheckBox)findViewById(R.id.enable_log)).setChecked(getSharedPreferences("debug",MODE_PRIVATE).getBoolean("enable_log",false));
        ((CheckBox)findViewById(R.id.enable_log)).setOnCheckedChangeListener(
                new CheckBox.OnCheckedChangeListener() {
                    @Override
                    public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                        SharedPreferences pref=getSharedPreferences("debug",MODE_PRIVATE);
                        pref.edit().putBoolean("enable_log",isChecked).apply();
                    }
                }
        );

        text.setText(Emulator.get.simple_device_info());
        text.setTextIsSelectable(true);
        text.setLongClickable(true);
    }
}
