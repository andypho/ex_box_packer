<?php
declare(strict_types=1);

require '/Users/andy/Repos/BoxPacker/vendor/autoload.php';

use DVDoug\BoxPacker\Box;
use DVDoug\BoxPacker\Item;
use DVDoug\BoxPacker\ItemList;
use DVDoug\BoxPacker\Rotation;
use DVDoug\BoxPacker\VolumePacker;

final class BenchItem implements Item
{
    public function __construct(
        private string $ref,
        private int $w,
        private int $l,
        private int $d,
        private int $wt
    ) {}
    public function getDescription(): string { return $this->ref; }
    public function getWidth(): int { return $this->w; }
    public function getLength(): int { return $this->l; }
    public function getDepth(): int { return $this->d; }
    public function getWeight(): int { return $this->wt; }
    public function getAllowedRotation(): Rotation { return Rotation::BestFit; }
}

final class BenchBox implements Box
{
    public function __construct(private int $iw, private int $il, private int $id, private int $mw) {}
    public function getReference(): string { return 'bench-box'; }
    public function getOuterWidth(): int { return $this->iw; }
    public function getOuterLength(): int { return $this->il; }
    public function getOuterDepth(): int { return $this->id; }
    public function getEmptyWeight(): int { return 0; }
    public function getInnerWidth(): int { return $this->iw; }
    public function getInnerLength(): int { return $this->il; }
    public function getInnerDepth(): int { return $this->id; }
    public function getMaxWeight(): int { return $this->mw; }
}

// --- read shared dataset ---
$boxRow = array_map('intval', explode(',', trim(file_get_contents('/tmp/packbench/box.csv'))));
[$bl, $bd, $bh, $bmw] = $boxRow;
$boxVol = $bl * $bd * $bh;

$allItems = [];
foreach (file('/tmp/packbench/items_all.csv', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
    $allItems[] = array_map('intval', explode(',', $line));
}

$Ns = [5, 10, 20, 40, 80];

printf("%-6s %-8s %-8s %-14s %-12s\n", "N", "fitted", "unfit", "util(%)", "time(ms)");
foreach ($Ns as $N) {
    $box = new BenchBox($bl, $bd, $bh, $bmw);
    $itemList = new ItemList();
    for ($i = 0; $i < $N; $i++) {
        [$d1, $d2, $d3, $wt] = $allItems[$i];
        $itemList->insert(new BenchItem("i$i", $d1, $d2, $d3, $wt));
    }

    $t0 = hrtime(true);
    $packer = new VolumePacker($box, $itemList);
    $packed = $packer->pack();
    $t1 = hrtime(true);

    $fitted = $packed->items->count();
    $util = round($packed->getVolumeUtilisation(), 1);
    $ms = round(($t1 - $t0) / 1e6, 2);

    printf("%-6d %-8d %-8d %-14s %-12s\n", $N, $fitted, $N - $fitted, $util, $ms);
}
