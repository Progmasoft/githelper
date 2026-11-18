// SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com>
// SPDX-License-Identifier: MIT-0

//go:build !windows

package console

import "os"

// enableEscapes reports whether a terminal understands escape sequences;
// terminals outside Windows do.
func enableEscapes(*os.File) bool {
	return true
}
