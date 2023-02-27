linux:
	flutter build linux --verbose --release
	rm -rf ~/opt/sudoku
	mkdir -p ~/opt/sudoku
	cp -r build/linux/x64/release/bundle/* ~/opt/sudoku/
	cp assets/sudoku.svg ~/opt/sudoku/icon.svg
	# cp assets/icon_transparent.svg ~/opt/sudoku/icon.svg
	rm -f ~/.local/share/applications/sudoku.desktop
	@echo "#!/usr/bin/env xdg-open" >> ~/.local/share/applications/sudoku.desktop
	@echo "" >> ~/.local/share/applications/sudoku.desktop
	@echo "[Desktop Entry]" >> ~/.local/share/applications/sudoku.desktop
	@echo "Version=1.0" >> ~/.local/share/applications/sudoku.desktop
	@echo "Terminal=false" >> ~/.local/share/applications/sudoku.desktop
	@echo "Type=Application" >> ~/.local/share/applications/sudoku.desktop
	@echo "Name=Sudoku" >> ~/.local/share/applications/sudoku.desktop
	@echo "" >> ~/.local/share/applications/sudoku.desktop
	@echo "Exec=${HOME}/opt/sudoku/sudoku" >> ~/.local/share/applications/sudoku.desktop
	@echo "Icon=${HOME}/opt/sudoku/icon.svg" >> ~/.local/share/applications/sudoku.desktop

page:
	rm -rf docs/*
	flutter build web -v
	cp -r -v build/web/* docs

android:
	flutter build apk
	flutter install --use-application-binary=build/app/outputs/flutter-apk/app-release.apk

.PHONY: linux android