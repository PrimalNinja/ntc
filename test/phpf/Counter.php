<?php
//# Option Flavour PHP
class Counter
{
	public $total = 0;        //#long
	private $nsteps = 0;
	public $label = "";

	public function add($n)
	{
		$this->total += $n;
		$this->bump();
	}

	private function bump()
	{
		$this->nsteps = $this->nsteps + 1;
	}

	public function steps()
	{
		return $this->nsteps;
	}

	public function describe()
	{
		return $this->label . "=" . $this->total;
	}
}
