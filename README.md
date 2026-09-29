# Plex for Windows · Dolby Vision Profile 5 color fix

[中文](#中文) · [English](#english)

This package replaces Plex for Windows' mpv DLL and adds three color settings. It tone maps Dolby Vision Profile 5 for normal colors on Windows; it does **not** output a native Dolby Vision signal. The scripts discover paths on each PC and contain no hard-coded user name or drive letter.

## 中文

### 自动安装与回退

1. 下载整个仓库（GitHub 页面选择 **Code → Download ZIP**），解压后保留 `assets` 中的两个文件。
2. 完全退出 Plex，然后双击 `Install.bat`。按提示用当前 Windows 账户同意 UAC 管理员权限。
3. 安装结束后打开 Plex，播放一部 Dolby Vision Profile 5 视频检查颜色。需要撤销时双击 `Restore.bat`。

适用于 **Plex for Windows 桌面客户端**，不适用于 Plex Media Server 或 Plex HTPC。只需 Windows 自带的 PowerShell 5.1；自动安装不需要联网或 7-Zip。脚本会在 Plex 安装目录把原 DLL 备份为 `libmpv-2.dll.bak`，在 `%LOCALAPPDATA%\Plex` 把已有配置备份为 `mpv.conf.bak`。若已自行替换过 DLL，请先恢复 Plex 原版，再运行自动安装。

### 手动安装与回退

1. 在系统托盘退出 Plex，并在任务管理器确认没有 `Plex.exe`。
2. 从[上游发布页](https://github.com/mitzsch/mpv-winbuild/releases/latest)下载名称以 **`mpv-dev-x86_64-`** 开头的标准 64 位 `.7z` 文件，用 7-Zip 解压出 `libmpv-2.dll`。如需使用本包验证过的版本，选[此发布版本](https://github.com/mitzsch/mpv-winbuild/releases/tag/2026-07-25-8c67647b50)中的 `mpv-dev-x86_64-20260725-git-4c952ac500.7z`。
3. 在资源管理器地址栏输入 `%ProgramFiles%\Plex\Plex`。如果 Plex 装在别处，就打开它实际的安装目录。把原 `libmpv-2.dll` 改名为 `libmpv-2.dll.bak`，再复制解压得到的新 DLL，保持文件名为 `libmpv-2.dll`。
4. 在资源管理器地址栏输入 `%LOCALAPPDATA%\Plex`。备份已有的 `mpv.conf`，然后在文件末尾加入以下设置；若文件不存在则新建，注意不要保存为 `mpv.conf.txt`：

   ```ini
   vo=gpu-next
   gpu-api=d3d11
   target-colorspace-hint-mode=target
   ```

5. 重新打开 Plex。手动回退时先退出 Plex，删除新 DLL，把 `.bak` 改回原文件名，再恢复原 `mpv.conf`；如果原本没有配置文件，就删除新建的配置文件。

### 自定义 DLL 与状态

自动脚本也可以安装你自行解压的 DLL，或者指定非默认 Plex 安装目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Plex-DoviMpv.ps1 -Action Install -DllPath '<libmpv-2.dll 的完整路径>' -PlexDir '<Plex 安装目录>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Plex-DoviMpv.ps1 -Action Status
```

`-DllPath` 和 `-PlexDir` 可分别单独使用。安装自己的 DLL 时建议附加 `-ExpectedSha256 '<DLL 的 SHA-256>'`。若安装后文件被更新或修改，回退会拒绝覆盖；确定要恢复旧备份时，可运行 `-Action Restore -Force`。

## English

### Automatic install and restore

1. Download the entire repository (**Code → Download ZIP** on GitHub), extract it, and keep both files in `assets`.
2. Fully quit Plex, then double-click `Install.bat`. Approve the UAC prompt using your current Windows account.
3. Open Plex and test a Dolby Vision Profile 5 video. Double-click `Restore.bat` to undo the change.

This targets the **Plex for Windows desktop app**, not Plex Media Server or Plex HTPC. It uses Windows PowerShell 5.1, which is included with Windows. Automatic installation needs neither an Internet connection nor 7-Zip. The original DLL is saved as `libmpv-2.dll.bak` beside Plex's DLL, and an existing config is saved as `mpv.conf.bak` in `%LOCALAPPDATA%\Plex`. If you previously replaced Plex's DLL yourself, restore the stock DLL before running the installer.

### Manual install and restore

1. Quit Plex from the system tray and confirm that `Plex.exe` is not running in Task Manager.
2. Download the standard 64-bit `.7z` archive beginning **`mpv-dev-x86_64-`** from the [upstream releases page](https://github.com/mitzsch/mpv-winbuild/releases/latest). Extract `libmpv-2.dll` with 7-Zip. For the build tested here, use `mpv-dev-x86_64-20260725-git-4c952ac500.7z` from [this release](https://github.com/mitzsch/mpv-winbuild/releases/tag/2026-07-25-8c67647b50).
3. Enter `%ProgramFiles%\Plex\Plex` in File Explorer's address bar, or open the actual Plex installation folder. Rename the original `libmpv-2.dll` to `libmpv-2.dll.bak`, then copy in the extracted DLL under the original name.
4. Enter `%LOCALAPPDATA%\Plex` in File Explorer. Back up an existing `mpv.conf`, then append these lines. Create the file if needed, taking care not to name it `mpv.conf.txt`:

   ```ini
   vo=gpu-next
   gpu-api=d3d11
   target-colorspace-hint-mode=target
   ```

5. Reopen Plex. To revert manually, quit Plex, remove the new DLL, rename the `.bak` file back, and restore the original `mpv.conf`. If there was no config before, delete the newly created one.

### Custom DLL and status

The automatic script can use your own extracted DLL and a custom Plex folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Plex-DoviMpv.ps1 -Action Install -DllPath '<full path to libmpv-2.dll>' -PlexDir '<Plex installation folder>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Plex-DoviMpv.ps1 -Action Status
```

Either path option may be used on its own. Add `-ExpectedSha256 '<DLL SHA-256>'` when installing your own DLL. Restore refuses to overwrite files changed after installation unless you explicitly use `-Action Restore -Force`.

## Bundle provenance / 附带文件来源

The bundled DLL is from [Mitzsch's `2026-07-25-8c67647b50` release](https://github.com/mitzsch/mpv-winbuild/releases/tag/2026-07-25-8c67647b50) and was tested with Plex for Windows `1.115.0.426`. The original DLL was not modified; its ZIP was divided into two parts so each file fits GitHub's [browser upload limit](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github). The installer joins the parts and verifies both the ZIP and DLL SHA-256 before replacing Plex's file.

| Item / 项目 | SHA-256 |
| --- | --- |
| Original upstream `.7z` / 上游原包 | `CA9A739CE5240D7619E682590BAFE142F0EF26F4956F0329D99251E903E6B174` |
| Joined ZIP / 合并后的 ZIP | `C2E944780FDAB2EDF50278A2EF30028F7EF06CD061E3B857612E993C004EE7BB` |
| `libmpv-2.dll` | `1B1D1A527FF6D81915E03F66A4536265D7D5A807117566CF42EF7F7AE8AF5C91` |

The build source and dependency list are in [mitzsch/mpv-winbuild](https://github.com/mitzsch/mpv-winbuild). mpv documents its default GPLv2-or-later license in its [Copyright file](https://github.com/mpv-player/mpv/blob/master/Copyright); see the source projects for license details of included components. / 构建来源及依赖见上游仓库；mpv 与其依赖的许可信息请查阅对应源项目。
